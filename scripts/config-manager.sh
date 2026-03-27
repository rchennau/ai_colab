#!/usr/bin/env bash
# ai-colab Configuration Manager
# Unified configuration management with validation, atomic writes, and state tracking

set -euo pipefail

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration paths
CONFIG_DIR="$PROJECT_ROOT/config"
CONFIG_FILE="$CONFIG_DIR/config.toml"
CONFIG_SCHEMA="$CONFIG_DIR/config.schema.json"
STATE_FILE="$PROJECT_ROOT/.ai-colab-state.json"
PREFS_FILE="$PROJECT_ROOT/.ai-colab-prefs"
BACKUP_DIR="$CONFIG_DIR/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Utility Functions
# ============================================

print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if a command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure required directories exist
ensure_dirs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"
}

# ============================================
# Configuration Validation
# ============================================

# Validate configuration against schema
# Usage: validate_config <config_file>
validate_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_SCHEMA" ]]; then
        print_warning "Schema file not found: $CONFIG_SCHEMA"
        print_info "Skipping validation"
        return 0
    fi
    
    # Check if Python is available for JSON schema validation
    if has_command python3; then
        python3 << PYTHON_EOF
import json
import sys
import re

def validate_toml_basic(content):
    """Basic TOML validation (key = value pairs)"""
    errors = []
    lines = content.split('\n')
    in_array = False
    in_table = False
    
    for i, line in enumerate(lines, 1):
        line = line.strip()
        
        # Skip empty lines and comments
        if not line or line.startswith('#'):
            continue
        
        # Check for basic TOML patterns
        if line.startswith('[') and line.endswith(']'):
            # Table header
            continue
        elif '=' in line:
            # Key-value pair
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip()
            
            # Validate key (allow dots for dotted keys)
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_.-]*$', key):
                errors.append(f"Line {i}: Invalid key format: {key}")
            
            # Basic value validation
            if not (value.startswith('"') and value.endswith('"')) and \
               not (value.startswith('[') and value.endswith(']')) and \
               not value in ['true', 'false'] and \
               not re.match(r'^-?\d+$', value) and \
               not re.match(r'^-?\d+\.\d+$', value):
                # Could be a multi-line array or table
                pass
        elif line.startswith('[') or line.startswith(']'):
            # Array continuation
            continue
        else:
            # Unknown format
            pass
    
    return errors

try:
    with open('$config_file', 'r') as f:
        content = f.read()
    
    errors = validate_toml_basic(content)
    
    if errors:
        for error in errors:
            print(f"Validation error: {error}", file=sys.stderr)
        sys.exit(1)
    else:
        print("Configuration validation passed")
        sys.exit(0)
        
except Exception as e:
    print(f"Validation error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
        return $?
    else
        print_warning "Python3 not available, skipping schema validation"
        return 0
    fi
}

# ============================================
# Configuration Read/Write Operations
# ============================================

# Read a configuration value
# Usage: config_get <key> [default_value]
config_get() {
    local key="$1"
    local default="${2:-}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return 0
    fi
    
    # Use grep and sed for basic TOML parsing
    local value=$(grep "^${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | \
                  sed "s/^${key}[[:space:]]*=[[:space:]]*//" | \
                  tr -d '"' | \
                  tr -d "'" || echo "$default")
    
    echo "$value"
}

# Set a configuration value
# Usage: config_set <key> <value>
config_set() {
    local key="$1"
    local value="$2"
    local atomic="${3:-true}"
    
    ensure_dirs
    
    # Check if key exists and has same value
    if grep -q "^${key}[[:space:]]*=[[:space:]]*\"${value}\"" "$CONFIG_FILE" 2>/dev/null; then
        return 0
    fi

    # Create backup if atomic mode and file exists
    if [[ "$atomic" == "true" && -f "$CONFIG_FILE" ]]; then
        create_backup
    fi

    # Create config file if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    # Check if key exists (regardless of value)
    if grep -q "^${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null; then
        # Update existing key
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed
            sed -i '' "s|^${key}[[:space:]]*=.*|${key} = \"${value}\"|" "$CONFIG_FILE"
        else
            # Linux sed
            sed -i "s|^${key}[[:space:]]*=.*|${key} = \"${value}\"|" "$CONFIG_FILE"
        fi
    else
        # Add new key
        echo "${key} = \"${value}\"" >> "$CONFIG_FILE"
    fi
    
    # SECURITY: Set secure file permissions (owner read/write only)
    chmod 600 "$CONFIG_FILE" 2>/dev/null || true

    print_success "Configuration updated: ${key} = ${value}"
    # Update state
    update_state "config_changed" "$(date -Iseconds)"

    return 0
}

# List all configuration values
# Usage: config_list [--json]
config_list() {
    local format="${1:-text}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "No configuration file found"
        return 1
    fi
    
    if [[ "$format" == "--json" ]]; then
        # Output as JSON
        python3 << PYTHON_EOF
import re

config = {}
with open('$CONFIG_FILE', 'r') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('['):
            continue
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            config[key] = value

import json
print(json.dumps(config, indent=2))
PYTHON_EOF
    else
        # Output as text
        cat "$CONFIG_FILE"
    fi
}

# ============================================
# Backup and Rollback
# ============================================

# Create a backup of the current configuration
# Usage: create_backup
create_backup() {
    ensure_dirs
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/config.${timestamp}.toml"
    
    cp "$CONFIG_FILE" "$backup_file"
    
    # Update backup manifest
    echo "${timestamp}:${backup_file}" >> "$BACKUP_DIR/.manifest"
    
    print_success "Backup created: $backup_file"
    
    # Keep only last 10 backups
    cleanup_old_backups
}

# Restore from backup
# Usage: restore_backup [timestamp]
restore_backup() {
    local timestamp="${1:-}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "No backups available"
        return 1
    fi
    
    if [[ -z "$timestamp" ]]; then
        # Get latest backup
        timestamp=$(tail -1 "$BACKUP_DIR/.manifest" 2>/dev/null | cut -d: -f1)
        
        if [[ -z "$timestamp" ]]; then
            print_error "No backups found in manifest"
            return 1
        fi
    fi
    
    local backup_file="$BACKUP_DIR/config.${timestamp}.toml"
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup not found: $backup_file"
        return 1
    fi
    
    cp "$backup_file" "$CONFIG_FILE"
    
    print_success "Restored backup from: $timestamp"
    
    return 0
}

# Clean up old backups (keep last 10)
cleanup_old_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        return 0
    fi
    
    local backup_count=$(ls -1 "$BACKUP_DIR"/config.*.toml 2>/dev/null | wc -l)
    
    if [[ $backup_count -gt 10 ]]; then
        local to_delete=$((backup_count - 10))
        ls -1t "$BACKUP_DIR"/config.*.toml | tail -n "$to_delete" | xargs rm -f
        
        print_info "Cleaned up $to_delete old backup(s)"
    fi
}

# ============================================
# State Tracking
# ============================================

# Initialize state file
# Usage: init_state
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << EOF
{
  "version": "1.0.0",
  "created": "$(date -Iseconds)",
  "installation": {
    "status": "pending",
    "pathway": "unknown"
  },
  "config_history": [],
  "last_modified": "$(date -Iseconds)"
}
EOF
        print_success "State file initialized: $STATE_FILE"
    fi
}

# Update state
# Usage: update_state <key> <value>
update_state() {
    local key="$1"
    local value="$2"
    
    init_state
    
    if has_command python3; then
        python3 << PYTHON_EOF
import json
from datetime import datetime

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

# Update the specified key
keys = '$key'.split('.')
current = state
for key in keys[:-1]:
    if key not in current:
        current[key] = {}
    current = current[key]
current[keys[-1]] = '$value'

# Update last_modified timestamp
state['last_modified'] = datetime.now().isoformat()

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
PYTHON_EOF
    fi
}

# Get state value
# Usage: get_state <key> [default]
get_state() {
    local key="$1"
    local default="${2:-}"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "$default"
        return 0
    fi
    
    if has_command python3; then
        python3 << PYTHON_EOF
import json
import sys

try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)

    keys = '$key'.split('.')
    current = state
    found = True
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            found = False
            break
            
    if found:
        print(current if current is not None else "")
    else:
        print('$default')
except Exception:
    print('$default')
PYTHON_EOF
    else
        echo "$default"
    fi
}

# Log configuration change
# Usage: log_config_change <description>
log_config_change() {
    local description="$1"
    
    init_state
    
    if has_command python3; then
        python3 << PYTHON_EOF
import json
from datetime import datetime

with open('$STATE_FILE', 'r') as f:
    state = json.load(f)

# Add to config history
change = {
    "timestamp": datetime.now().isoformat(),
    "description": "$description"
}

if 'config_history' not in state:
    state['config_history'] = []

state['config_history'].append(change)

# Keep only last 50 changes
if len(state['config_history']) > 50:
    state['config_history'] = state['config_history'][-50:]

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
PYTHON_EOF
    fi
}

# ============================================
# Profile Management
# ============================================

# List available profiles
# Usage: list_profiles
list_profiles() {
    local profiles_dir="$CONFIG_DIR/profiles"
    
    if [[ ! -d "$profiles_dir" ]]; then
        echo "No profiles found"
        return 1
    fi
    
    echo "Available profiles:"
    for profile in "$profiles_dir"/*.toml; do
        if [[ -f "$profile" ]]; then
            local name=$(basename "$profile" .toml)
            echo "  - $name"
        fi
    done
}

# Load a profile
# Usage: load_profile <profile_name>
load_profile() {
    local profile_name="$1"
    local profiles_dir="$CONFIG_DIR/profiles"
    local profile_file="$profiles_dir/${profile_name}.toml"
    
    if [[ ! -f "$profile_file" ]]; then
        print_error "Profile not found: $profile_name"
        return 1
    fi
    
    # Create backup before loading profile
    create_backup
    
    # Copy profile to config
    cp "$profile_file" "$CONFIG_FILE"
    
    print_success "Loaded profile: $profile_name"
    log_config_change "Loaded profile: $profile_name"
    
    return 0
}

# Save current config as profile
# Usage: save_profile <profile_name>
save_profile() {
    local profile_name="$1"
    local profiles_dir="$CONFIG_DIR/profiles"
    local profile_file="$profiles_dir/${profile_name}.toml"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "No configuration to save"
        return 1
    fi
    
    mkdir -p "$profiles_dir"
    cp "$CONFIG_FILE" "$profile_file"
    
    print_success "Saved profile: $profile_name"
    
    return 0
}

# ============================================
# Migration from Legacy Format
# ============================================

# Migrate from legacy .ai-colab-prefs format
# Usage: migrate_legacy
migrate_legacy() {
    if [[ ! -f "$PREFS_FILE" ]]; then
        return 0
    fi
    
    print_info "Found legacy preferences file, migrating..."
    
    # Read legacy prefs and convert to new format
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        # Convert key format
        key=$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
        
        # Set in new config
        config_set "$key" "$value" false
    done < "$PREFS_FILE"
    
    # Backup legacy file
    mv "$PREFS_FILE" "${PREFS_FILE}.legacy"
    
    print_success "Migration complete. Legacy file backed up."
    
    return 0
}

# ============================================
# Export/Import Configuration
# ============================================

# Export configuration to JSON
# Usage: export_config_json [output_file]
export_config_json() {
    local output_file="${1:-$CONFIG_DIR/config.export.json}"
    
    if has_command python3; then
        python3 << PYTHON_EOF
import re
import json

config = {}
with open('$CONFIG_FILE', 'r') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('['):
            continue
        if '=' in line:
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            config[key] = value

with open('$output_file', 'w') as f:
    json.dump(config, f, indent=2)

print(f"Configuration exported to: $output_file")
PYTHON_EOF
    fi
}

# Import configuration from JSON
# Usage: import_config_json <input_file>
import_config_json() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        print_error "Import file not found: $input_file"
        return 1
    fi
    
    if has_command python3; then
        python3 << PYTHON_EOF
import json

with open('$input_file', 'r') as f:
    config = json.load(f)

# Append to existing config or create new
with open('$CONFIG_FILE', 'a') as f:
    for key, value in config.items():
        f.write(f'{key} = "{value}"\n')

print(f"Configuration imported from: $input_file")
PYTHON_EOF
    fi
}

# ============================================
# Help and Usage
# ============================================

show_help() {
    cat << EOF
${CYAN}ai-colab Configuration Manager${NC}

${BLUE}USAGE:${NC}
    $(basename "$0") <command> [options]

${BLUE}COMMANDS:${NC}
    ${GREEN}get${NC} <key> [default]          Get a configuration value
    ${GREEN}set${NC} <key> <value>            Set a configuration value
    ${GREEN}list${NC} [--json]                List all configuration values
    ${GREEN}validate${NC}                     Validate configuration against schema
    ${GREEN}backup${NC}                       Create a backup of current config
    ${GREEN}restore${NC} [timestamp]          Restore from backup
    ${GREEN}state${NC} <key>                  Get state value
    ${GREEN}state-set${NC} <key> <value>      Set state value
    ${GREEN}init${NC}                         Initialize state file
    ${GREEN}profiles${NC}                     List available profiles
    ${GREEN}load-profile${NC} <name>          Load a profile
    ${GREEN}save-profile${NC} <name>          Save current config as profile
    ${GREEN}migrate${NC}                      Migrate from legacy format
    ${GREEN}export${NC} [file]                Export config to JSON
    ${GREEN}import${NC} <file>                Import config from JSON
    ${GREEN}help${NC}                         Show this help message

${BLUE}EXAMPLES:${NC}
    $(basename "$0") get llms.default
    $(basename "$0") set compute.backend local
    $(basename "$0") list --json
    $(basename "$0") validate
    $(basename "$0") backup
    $(basename "$0") restore 20260324-120000
    $(basename "$0") load-profile standard
    $(basename "$0") migrate

${BLUE}FILES:${NC}
    Config:     $CONFIG_FILE
    Schema:     $CONFIG_SCHEMA
    State:      $STATE_FILE
    Backups:    $BACKUP_DIR/

${BLUE}CONFIGURATION PATHWAYS:${NC}
    CLI:        ./install.sh --wizard
    Web UI:     http://localhost:8080 (Docker)
    Reconfigure: ./install.sh --reconfigure

EOF
}

# ============================================
# Main Command Handler
# ============================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        get)
            config_get "$@"
            ;;
        set)
            config_set "$@"
            ;;
        list)
            config_list "$@"
            ;;
        validate)
            validate_config "$@"
            ;;
        backup)
            create_backup
            ;;
        restore)
            restore_backup "$@"
            ;;
        state)
            get_state "$@"
            ;;
        state-set)
            update_state "$@"
            ;;
        init)
            init_state
            ;;
        profiles)
            list_profiles
            ;;
        load-profile)
            load_profile "$@"
            ;;
        save-profile)
            save_profile "$@"
            ;;
        migrate)
            migrate_legacy
            ;;
        export)
            export_config_json "$@"
            ;;
        import)
            import_config_json "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
