#!/usr/bin/env bash
# Module Manager - Parse and manage ai-colab module manifests
# Provides utilities for discovering, parsing, and loading module configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default modules directory
MODULES_DIR="${MODULES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/modules}"

# ============================================
# TOML Parsing Helpers
# ============================================

# Extract a simple value from TOML (handles strings, numbers, booleans)
# Usage: parse_toml_value "key = value" "key"
parse_toml_value() {
    local line="$1"
    local key="$2"
    
    # Handle spaces around = and remove quotes
    echo "$line" | sed -n "s/^${key}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

# Extract a string array from TOML
# Usage: parse_toml_array "key = [\"val1\", \"val2\"]" "key"
parse_toml_array() {
    local line="$1"
    local key="$2"
    
    # Extract array content and split by comma
    echo "$line" | sed -n "s/^${key}[[:space:]]*=[[:space:]]*\[\(.*\)\]$/\1/p" | \
        tr ',' '\n' | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//' | grep -v '^$'
}

# Extract inline table array from TOML (for hooks)
# Usage: parse_toml_inline_tables "key = [{a=1, b=2}, {a=3, b=4}]" "key"
parse_toml_inline_tables() {
    local content="$1"
    local key="$2"
    
    # Extract the array content
    local array_content=$(echo "$content" | sed -n "/^${key}[[:space:]]*=/s/^${key}[[:space:]]*=[[:space:]]*\[\(.*\)\]$/\1/p")
    
    if [[ -z "$array_content" ]]; then
        return
    fi
    
    # Split by },{ and process each table
    echo "$array_content" | sed 's/},[[:space:]]*{/}\n{/g' | while read -r table; do
        # Clean up brackets and spaces
        table=$(echo "$table" | tr -d '{}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        echo "$table"
    done
}

# Get value from inline table
# Usage: get_inline_table_value "{trigger=\"!screenshot\", script=\"test.sh\"}" "trigger"
get_inline_table_value() {
    local table="$1"
    local key="$2"
    
    echo "$table" | sed -n "s/.*${key}[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

# ============================================
# Module Discovery
# ============================================

# Find all modules with valid manifests
# Usage: discover_modules
discover_modules() {
    local modules=()
    
    if [[ ! -d "$MODULES_DIR" ]]; then
        echo -e "${YELLOW}Warning: Modules directory not found: $MODULES_DIR${NC}" >&2
        return 1
    fi
    
    # Find all module.toml files
    for module_dir in "$MODULES_DIR"/*/; do
        if [[ -f "${module_dir}module.toml" ]]; then
            local module_id=$(basename "$module_dir")
            modules+=("$module_id")
        fi
    done
    
    # Output module IDs
    printf '%s\n' "${modules[@]}"
}

# Check if a module is active (enabled)
# Usage: is_module_active "module-id"
is_module_active() {
    local module_id="$1"
    # Convert to uppercase and replace hyphens with underscores
    local env_var_name=$(echo "$module_id" | tr '[:lower:]-' '[:upper:]_')
    local env_var="ENABLE_${env_var_name}"
    
    [[ "${!env_var:-}" == "true" ]]
}

# Get module directory path
# Usage: get_module_dir "module-id"
get_module_dir() {
    local module_id="$1"
    echo "$MODULES_DIR/$module_id"
}

# Get module manifest path
# Usage: get_module_manifest "module-id"
get_module_manifest() {
    local module_id="$1"
    echo "$MODULES_DIR/$module_id/module.toml"
}

# Get module init script
# Usage: get_init_script "module-id"
get_init_script() {
    local module_id="$1"
    local manifest=$(get_module_manifest "$module_id")
    
    if [[ ! -f "$manifest" ]]; then
        return 1
    fi
    
    # Extract init_script value
    grep "^init_script[[:space:]]*=[[:space:]]*" "$manifest" | cut -d'"' -f2
}

# ============================================
# Module Metadata Extraction
# ============================================

# Parse module metadata from manifest
# Usage: parse_module_metadata "module-id"
# Returns: JSON-like output with module info
parse_module_metadata() {
    local module_id="$1"
    local manifest=$(get_module_manifest "$module_id")
    
    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}Error: Module manifest not found: $manifest${NC}" >&2
        return 1
    fi
    
    local id="" name="" description="" version=""
    local in_module_section=false
    
    while IFS= read -r line; do
        # Detect section
        if [[ "$line" =~ ^\[module\] ]]; then
            in_module_section=true
            continue
        elif [[ "$line" =~ ^\[ ]]; then
            in_module_section=false
            continue
        fi
        
        # Parse module section
        if [[ "$in_module_section" == true ]]; then
            case "$line" in
                id\ =*) id=$(parse_toml_value "$line" "id") ;;
                name\ =*) name=$(parse_toml_value "$line" "name") ;;
                description\ =*) description=$(parse_toml_value "$line" "description") ;;
                version\ =*) version=$(parse_toml_value "$line" "version") ;;
            esac
        fi
    done < "$manifest"
    
    # Output metadata
    echo "id=$id"
    echo "name=$name"
    echo "description=$description"
    echo "version=$version"
}

# ============================================
# Environment Variables
# ============================================

# Extract environment variables from module manifest
# Usage: parse_module_env "module-id"
parse_module_env() {
    local module_id="$1"
    local manifest=$(get_module_manifest "$module_id")
    
    if [[ ! -f "$manifest" ]]; then
        return 1
    fi
    
    local in_env_section=false
    
    while IFS= read -r line; do
        # Detect section
        if [[ "$line" =~ ^\[env\] ]]; then
            in_env_section=true
            continue
        elif [[ "$line" =~ ^\[ ]]; then
            in_env_section=false
            continue
        fi
        
        # Parse env section (KEY = "value")
        if [[ "$in_env_section" == true && "$line" =~ ^[A-Z_]+[[:space:]]*= ]]; then
            local key=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
            local value=$(parse_toml_value "$line" "$key")
            echo "${key}=${value}"
        fi
    done < "$manifest"
}

# Export environment variables for a module
# Usage: export_module_env "module-id"
export_module_env() {
    local module_id="$1"
    
    while IFS='=' read -r key value; do
        if [[ -n "$key" ]]; then
            export "$key=$value"
            echo -e "${BLUE}Exported:${NC} $key=$value"
        fi
    done < <(parse_module_env "$module_id")
}

# ============================================
# Command Hooks
# ============================================

# Parse conductor command hooks from module manifest
# Usage: parse_conductor_commands "module-id"
# Output: trigger|script pairs, one per line
parse_conductor_commands() {
    local module_id="$1"
    local manifest=$(get_module_manifest "$module_id")
    
    if [[ ! -f "$manifest" ]]; then
        return 1
    fi
    
    # Read entire file and find conductor_commands array
    local content=$(cat "$manifest")
    local in_commands=false
    local bracket_count=0
    
    while IFS= read -r line; do
        # Look for conductor_commands start
        if [[ "$line" =~ conductor_commands[[:space:]]*= ]]; then
            in_commands=true
            bracket_count=1
            
            # Check if it's a single-line array
            if [[ "$line" =~ \] ]]; then
                # Parse single-line format
                parse_toml_inline_tables "$line" "conductor_commands" | while read -r table; do
                    local trigger=$(get_inline_table_value "$table" "trigger")
                    local script=$(get_inline_table_value "$table" "script")
                    if [[ -n "$trigger" && -n "$script" ]]; then
                        echo "${trigger}|${script}"
                    fi
                done
                in_commands=false
            fi
            continue
        fi
        
        # Multi-line array parsing
        if [[ "$in_commands" == true ]]; then
            # Count brackets
            local open_brackets=$(echo "$line" | tr -cd '[' | wc -c)
            local close_brackets=$(echo "$line" | tr -cd ']' | wc -c)
            bracket_count=$((bracket_count + open_brackets - close_brackets))
            
            # Extract inline tables from this line
            echo "$line" | grep -o '{[^}]*}' | while read -r table; do
                local trigger=$(get_inline_table_value "$table" "trigger")
                local script=$(get_inline_table_value "$table" "script")
                if [[ -n "$trigger" && -n "$script" ]]; then
                    echo "${trigger}|${script}"
                fi
            done
            
            # End of array
            if [[ $bracket_count -le 0 ]]; then
                in_commands=false
            fi
        fi
    done < "$manifest"
}

# Parse all conductor commands from all active modules
# Usage: parse_all_conductor_commands
# Output: trigger|script|module_id triples, one per line
parse_all_conductor_commands() {
    local modules=$(discover_modules)
    
    while IFS= read -r module_id; do
        if [[ -n "$module_id" ]] && is_module_active "$module_id"; then
            parse_conductor_commands "$module_id" | while IFS='|' read -r trigger script; do
                if [[ -n "$trigger" ]]; then
                    echo "${trigger}|${script}|${module_id}"
                fi
            done
        fi
    done <<< "$modules"
}

# ============================================
# Dashboard Sections
# ============================================

# Parse dashboard sections from module manifest
# Usage: parse_dashboard_sections "module-id"
# Output: name|type|source triples, one per line
parse_dashboard_sections() {
    local module_id="$1"
    local manifest=$(get_module_manifest "$module_id")
    
    if [[ ! -f "$manifest" ]]; then
        return 1
    fi
    
    local content=$(cat "$manifest")
    local in_sections=false
    local bracket_count=0
    
    while IFS= read -r line; do
        # Look for dashboard_sections start
        if [[ "$line" =~ dashboard_sections[[:space:]]*= ]]; then
            in_sections=true
            bracket_count=1
            
            # Check if it's a single-line array
            if [[ "$line" =~ \] ]]; then
                parse_toml_inline_tables "$line" "dashboard_sections" | while read -r table; do
                    local name=$(get_inline_table_value "$table" "name")
                    local type=$(get_inline_table_value "$table" "type")
                    local source=$(get_inline_table_value "$table" "source")
                    if [[ -n "$name" && -n "$type" && -n "$source" ]]; then
                        echo "${name}|${type}|${source}"
                    fi
                done
                in_sections=false
            fi
            continue
        fi
        
        # Multi-line array parsing
        if [[ "$in_sections" == true ]]; then
            local open_brackets=$(echo "$line" | tr -cd '[' | wc -c)
            local close_brackets=$(echo "$line" | tr -cd ']' | wc -c)
            bracket_count=$((bracket_count + open_brackets - close_brackets))
            
            # Extract inline tables from this line
            echo "$line" | grep -o '{[^}]*}' | while read -r table; do
                local name=$(get_inline_table_value "$table" "name")
                local type=$(get_inline_table_value "$table" "type")
                local source=$(get_inline_table_value "$table" "source")
                if [[ -n "$name" && -n "$type" && -n "$source" ]]; then
                    echo "${name}|${type}|${source}"
                fi
            done
            
            if [[ $bracket_count -le 0 ]]; then
                in_sections=false
            fi
        fi
    done < "$manifest"
}

# ============================================
# Module Loading
# ============================================

# Load all active modules
# Usage: load_all_modules
load_all_modules() {
    echo -e "${BLUE}=== Loading Modules ===${NC}"
    
    local modules=$(discover_modules)
    local loaded=0
    
    while IFS= read -r module_id; do
        if [[ -n "$module_id" ]]; then
            # Convert to uppercase and replace hyphens with underscores
            local env_var_name=$(echo "$module_id" | tr '[:lower:]-' '[:upper:]_')
            local env_var="ENABLE_${env_var_name}"
            
            # Auto-enable if no explicit setting
            if [[ -z "${!env_var:-}" ]]; then
                export "$env_var=true"
            fi
            
            if is_module_active "$module_id"; then
                echo -e "${GREEN}Loading:${NC} $module_id"
                export_module_env "$module_id"
                ((loaded++))
            else
                echo -e "${YELLOW}Skipping:${NC} $module_id (disabled)"
            fi
        fi
    done <<< "$modules"
    
    echo -e "${BLUE}Loaded $loaded module(s)${NC}"
}

# ============================================
# Command Line Interface
# ============================================

show_help() {
    cat << EOF
Module Manager - ai-colab Module Management Utility

Usage: $(basename "$0") <command> [options]

Commands:
    list                    List all available modules
    active                  List active modules
    info <module_id>        Show module metadata
    env <module_id>         Show module environment variables
    commands <module_id>    Show conductor commands from module
    dashboard <module_id>   Show dashboard sections from module
    load                    Load all active modules (export env vars)
    help                    Show this help message

Examples:
    $(basename "$0") list
    $(basename "$0") info example-module
    $(basename "$0") commands example-module
    $(basename "$0") load

Environment Variables:
    MODULES_DIR             Path to modules directory (default: ./modules)

EOF
}

# Main CLI handler
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        list)
            echo -e "${BLUE}Available Modules:${NC}"
            discover_modules | while read -r module_id; do
                if [[ -n "$module_id" ]]; then
                    if is_module_active "$module_id"; then
                        echo -e "  ${GREEN}✓${NC} $module_id (active)"
                    else
                        echo -e "  ${YELLOW}○${NC} $module_id"
                    fi
                fi
            done
            ;;
        active)
            echo -e "${BLUE}Active Modules:${NC}"
            discover_modules | while read -r module_id; do
                if [[ -n "$module_id" ]] && is_module_active "$module_id"; then
                    echo "  $module_id"
                fi
            done
            ;;
        info)
            if [[ -z "$1" ]]; then
                echo -e "${RED}Error: Module ID required${NC}"
                exit 1
            fi
            parse_module_metadata "$1"
            ;;
        env)
            if [[ -z "$1" ]]; then
                echo -e "${RED}Error: Module ID required${NC}"
                exit 1
            fi
            parse_module_env "$1"
            ;;
        commands)
            local raw=false
            if [[ "$1" == "--raw" ]]; then
                raw=true
                shift
            fi
            if [[ -z "$1" ]]; then
                echo -e "${RED}Error: Module ID required${NC}"
                exit 1
            fi
            if [[ "$1" == "all" ]]; then
                # List commands from all active modules (for !help)
                parse_all_conductor_commands | while IFS='|' read -r trigger script module_id; do
                    if [[ -n "$trigger" ]]; then
                        if [[ "$raw" == true ]]; then
                            echo "${trigger}|${script}|${module_id}"
                        else
                            echo "  $trigger → $script ($module_id)"
                        fi
                    fi
                done
            else
                [[ "$raw" == false ]] && echo -e "${BLUE}Conductor Commands:${NC}"
                parse_conductor_commands "$1" | while IFS='|' read -r trigger script; do
                    if [[ -n "$trigger" ]]; then
                        if [[ "$raw" == true ]]; then
                            echo "${trigger}|${script}"
                        else
                            echo "  $trigger → $script"
                        fi
                    fi
                done
            fi
            ;;
        dashboard)
            if [[ -z "$1" ]]; then
                echo -e "${RED}Error: Module ID required${NC}"
                exit 1
            fi
            echo -e "${BLUE}Dashboard Sections:${NC}"
            parse_dashboard_sections "$1" | while IFS='|' read -r name type source; do
                if [[ -n "$name" ]]; then
                    echo "  $name ($type): $source"
                fi
            done
            ;;
        init)
            if [[ -z "$1" ]]; then
                echo -e "${RED}Error: Module ID required${NC}"
                exit 1
            fi
            get_init_script "$1"
            ;;
        load)
            load_all_modules
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
