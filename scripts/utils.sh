#!/usr/bin/env bash
# Shared utilities for ai-colab scripts

# Ensure ~/.local/bin is in PATH for hcom
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# ============================================
# Logging Integration
# ============================================

# Source centralized logging
# Use UTILS_DIR to avoid overwriting SCRIPT_DIR from calling script
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$UTILS_DIR/logging.sh" ]]; then
    source "$UTILS_DIR/logging.sh"
fi

# Initialize logging for scripts that source utils
if type -t init_logging &> /dev/null; then
    init_logging "$(basename "$0")" 2>/dev/null || true
fi

# ============================================
# UI & ANSI Graphics Utilities (Dynamic Width)
# ============================================

# Detect terminal width with fallback
if command -v tput >/dev/null 2>&1; then
    UI_WIDTH=$(tput cols)
elif command -v stty >/dev/null 2>&1; then
    UI_WIDTH=$(stty size | cut -d' ' -f2)
else
    UI_WIDTH=80
fi

# Cap width at 100 for readability on ultra-wide screens, but ensure min 80
if [ $UI_WIDTH -gt 100 ]; then UI_WIDTH=100; fi
if [ $UI_WIDTH -lt 80 ]; then UI_WIDTH=80; fi

# UI Border Characters
UL="╔"
UR="╗"
LL="╚"
LR="╝"
HL="═"
VL="║"
ML="╠"
MR="╣"

# Colors (expanded)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Draw a horizontal line
ui_line() {
    local char="${1:-$HL}"
    local color="${2:-$BLUE}"
    local line=""
    for ((i=0; i<UI_WIDTH; i++)); do line+="$char"; done
    echo -e "${color}${line}${NC}"
}

# Draw a centered title with borders
ui_banner() {
    local title="$1"
    local color="${2:-$BLUE}"
    local padding=$(( (UI_WIDTH - ${#title} - 2) / 2 ))
    
    local top="$UL"
    local mid="$VL"
    local bot="$LL"
    
    for ((i=0; i<UI_WIDTH-2; i++)); do top+="$HL"; bot+="$HL"; done
    top+="$UR"
    bot+="$LR"
    
    echo -e "${color}${top}${NC}"
    
    # Calculate centering
    local left_pad=""
    for ((i=0; i<padding; i++)); do left_pad+=" "; done
    local right_pad=""
    local right_pad_len=$(( UI_WIDTH - 2 - padding - ${#title} ))
    for ((i=0; i<right_pad_len; i++)); do right_pad+=" "; done
    
    echo -e "${color}${mid}${NC}${BOLD}${left_pad}${title}${right_pad}${color}${mid}${NC}"
    echo -e "${color}${bot}${NC}"
}

# Draw a section title
ui_title() {
    local title=" $1 "
    local color="${2:-$CYAN}"
    local line_char="${3:-$HL}"
    
    local title_len=${#title}
    local left_len=$(( (UI_WIDTH - title_len) / 2 ))
    local right_len=$(( UI_WIDTH - title_len - left_len ))
    
    local left_line=""
    for ((i=0; i<left_len; i++)); do left_line+="$line_char"; done
    local right_line=""
    for ((i=0; i<right_len; i++)); do right_line+="$line_char"; done
    
    echo -e "\n${color}${left_line}${NC}${BOLD}${title}${NC}${color}${right_line}${NC}"
}

# Draw a box around multiple lines of text
ui_box() {
    local color="${2:-$BLUE}"
    local top="$UL"
    local bot="$LL"
    for ((i=0; i<UI_WIDTH-2; i++)); do top+="$HL"; bot+="$HL"; done
    top+="$UR"
    bot+="$LR"
    
    echo -e "${color}${top}${NC}"
    while IFS= read -r line; do
        # Strip ANSI codes for length calculation
        local clean_line=$(echo -e "$line" | sed 's/\x1B\[[0-9;]*[JKmsu]//g')
        local padding=$(( UI_WIDTH - 4 - ${#clean_line} ))
        local pad_str=""
        if [ $padding -gt 0 ]; then
            for ((i=0; i<padding; i++)); do pad_str+=" "; done
        fi
        echo -e "${color}${VL}${NC}  ${line}${pad_str}  ${color}${VL}${NC}"
    done <<< "$1"
    echo -e "${color}${bot}${NC}"
}

# Display a status item
ui_status() {
    local label="$1"
    local value="$2"
    local color="${3:-$GREEN}"
    
    local label_len=${#label}
    local dots=""
    local dots_len=$(( UI_WIDTH - label_len - ${#value} - 4 ))
    for ((i=0; i<dots_len; i++)); do dots+="."; done
    
    echo -e "  ${BOLD}${label}${NC} ${BLUE}${dots}${NC} ${color}${value}${NC}"
}

# Logging Utilities
log_info() { echo -e "${BLUE}[$(date +%T)] INFO:${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +%T)] SUCCESS:${NC} $1"; }
log_warn() { echo -e "${YELLOW}[$(date +%T)] WARNING:${NC} $1"; }
log_error() { echo -e "${RED}[$(date +%T)] ERROR:${NC} $1"; }

# Fleet Management Utilities
fleet_exec() {
    local host="$1"
    local cmd="$2"
    log_info "Executing remote command on $host: $cmd"
    ssh -o ConnectTimeout=5 "$host" "$cmd"
}

# Check if a command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check for hcom and warn if missing
check_hcom() {
    if ! has_command hcom; then
        echo -e "${YELLOW}Warning: hcom is not installed.${NC}" >&2
        echo -e "Some features (messaging, status tracking, blackboard) will be disabled." >&2
        echo -e "To install hcom, visit: https://github.com/hcom-org/hcom" >&2
        return 1
    fi
    return 0
}

# Check for sqlite3
check_sqlite3() {
    if ! has_command sqlite3; then
        echo -e "${RED}Error: sqlite3 is not installed.${NC}" >&2
        echo -e "This is required for the Shared Blackboard (hcom-kv)." >&2
        return 1
    fi
    return 0
}

# Cross-platform file modification time
get_file_mtime() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "N/A"
        return
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD stat)
        stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file"
    else
        # Linux (GNU stat)
        stat -c %y "$file" | cut -d'.' -f1
    fi
}

# Detect project root
detect_project_root() {
    local dir="${1:-$PWD}"
    while [[ "$dir" != "/" && "$dir" != "." ]]; do
        if [ -f "$dir/conductor/tracks.md" ] || [ -f "$dir/conductor/product.md" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    
    # Fallback: check where the scripts are located relative to this utils file
    local utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$utils_dir/../conductor/tracks.md" ]]; then
        echo "$(cd "$utils_dir/.." && pwd)"
        return 0
    fi

    return 1
}

# Get hcom database path
get_hcom_db_path() {
    echo "${HCOM_DB_PATH:-$HOME/.hcom/hcom.db}"
}

# Extract value from compact JSON (key:value or key:"value" or key:bool)
extract_json_value() {
    local json="$1"
    local key="$2"
    # Try string value first
    local val=$(echo "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")
    if [[ -z "$val" ]]; then
        # Try numeric value
        val=$(echo "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p")
    fi
    if [[ -z "$val" ]]; then
        # Try boolean (true/false) or null value
        val=$(echo "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\([a-z]*\).*/\1/p")
    fi
    echo "$val"
}

# Blackboard Helpers (hcom-kv)

blackboard_set() {
    local key="$1"
    local value="$2"
    local db_path=$(get_hcom_db_path)

    # Ensure directory exists
    mkdir -p "$(dirname "$db_path")"
    
    # Create basic structure if it doesn't exist
    sqlite3 "$db_path" "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT);" || {
        echo -e "${RED}Error: Failed to access blackboard at $db_path${NC}" >&2
        return 1
    }

    sqlite3 "$db_path" ".timeout 5000" "INSERT OR REPLACE INTO kv (key, value) VALUES ('$key', '$value');"
}

blackboard_get() {
    local key="$1"
    local db_path=$(get_hcom_db_path)

    if [[ ! -f "$db_path" ]]; then
        return 0
    fi

    sqlite3 "$db_path" ".timeout 5000" "SELECT value FROM kv WHERE key = '$key';"
}

# Usage: blackboard_list "pattern" (e.g. "fleet_health_")
blackboard_list() {
    local pattern="${1:-%}"
    # Append wildcard if not present
    [[ "$pattern" != *"%" ]] && pattern="${pattern}%"
    
    local db_path=$(get_hcom_db_path)

    if [[ ! -f "$db_path" ]]; then
        return 0
    fi

    sqlite3 "$db_path" ".timeout 5000" "SELECT key, value FROM kv WHERE key LIKE '$pattern';"
}

# hcom Agent Helpers

register_hcom() {
    local tool_name="$1"
    if has_command hcom; then
        # Use underscore instead of hyphen for hcom 0.7.5 compatibility
        # Using $$ for PID to ensure uniqueness if HCOM_NAME is not set
        local name="${HCOM_NAME:-${tool_name}_$$}"
        export HCOM_NAME="$name"

        # Register the agent with hcom and keep it persistent
        # We don't start a background listen here because it overwrites status
        hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
        return 0
    fi
    return 1
}

# Report agent health metrics to the Blackboard
# Usage: report_health "status" "latency_ms" "load"
report_health() {
    local status="${1:-ready}"
    local latency="${2:-0}"
    local load="${3:-0}"
    
    if [ -n "${HCOM_NAME:-}" ]; then
        local timestamp=$(date +%s)
        # Construct a simple JSON-like string for the value
        # Note: We avoid complex JSON tools in utils.sh for maximum portability
        local health_data="{\"status\":\"$status\",\"latency\":$latency,\"load\":$load,\"ts\":$timestamp}"
        blackboard_set "fleet_health_${HCOM_NAME}" "$health_data"
        return 0
    fi
    return 1
}

# ============================================================
# Blackboard Schema Validation (P16.3)
# ============================================================

# Schema and DB path overrides (for testing)
BLACKBOARD_SCHEMA_PATH="${BLACKBOARD_SCHEMA_PATH:-$PROJECT_ROOT/config/blackboard-schema.json}"
BLACKBOARD_DB_PATH="${BLACKBOARD_DB_PATH:-}"

# Get the blackboard database path (respects test override)
_bb_get_db_path() {
    if [[ -n "$BLACKBOARD_DB_PATH" ]]; then
        echo "$BLACKBOARD_DB_PATH"
    else
        get_hcom_db_path
    fi
}

# Ensure kv table exists with expires_at column
_bb_ensure_table() {
    local db_path="$(_bb_get_db_path)"
    mkdir -p "$(dirname "$db_path")"
    sqlite3 "$db_path" "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT, expires_at INTEGER DEFAULT 0);"
}

# Validate a key against the schema namespaces
# Returns 0 if valid, 1 if invalid, outputs error message to stderr
bb_validate_key() {
    local key="$1"
    local schema_path="${2:-$BLACKBOARD_SCHEMA_PATH}"

    # Check key length
    if [[ ${#key} -gt 256 ]]; then
        echo "Error: Key exceeds max length (256 chars)" >&2
        return 1
    fi

    # If schema not available, allow all writes with warning
    if [[ ! -f "$schema_path" ]]; then
        return 0
    fi

    # Check reserved namespaces first
    while IFS= read -r prefix; do
        prefix=$(echo "$prefix" | sed 's/[" ,]//g')
        if [[ -n "$prefix" && "$key" == "$prefix"* ]]; then
            echo "Error: Key '$key' uses reserved namespace '$prefix'" >&2
            return 1
        fi
    done < <(python3 -c "
import json, sys
try:
    schema = json.load(open('$schema_path'))
    for ns in schema.get('reserved_namespaces', []):
        print(ns)
except:
    pass
" 2>/dev/null)

    # Check against valid namespaces
    local key_valid
    key_valid=$(python3 -c "
import json, sys
try:
    schema = json.load(open('$schema_path'))
    key = '$key'
    valid = False
    for ns, config in schema.get('namespaces', {}).items():
        if key.startswith(ns):
            valid = True
            break
    print('valid' if valid else 'invalid')
except:
    print('valid')  # If schema parsing fails, allow all
" 2>/dev/null)

    if [[ "$key_valid" != "valid" ]]; then
        echo "Error: Key '$key' does not match any valid namespace" >&2
        return 1
    fi

    return 0
}

# Get TTL for a key from schema
bb_get_ttl_for_key() {
    local key="$1"
    local schema_path="${2:-$BLACKBOARD_SCHEMA_PATH}"

    if [[ ! -f "$schema_path" ]]; then
        echo "0"
        return
    fi

    local ttl
    ttl=$(python3 -c "
import json, sys
try:
    schema = json.load(open('$schema_path'))
    key = '$key'
    for ns, config in schema.get('namespaces', {}).items():
        if key.startswith(ns):
            print(config.get('default_ttl', 0))
            sys.exit(0)
    print(0)
except:
    print(0)
" 2>/dev/null)

    echo "${ttl:-0}"
}

# Validate value length
bb_validate_value_length() {
    local value="$1"
    local max_len="${2:-65536}"

    if [[ ${#value} -gt $max_len ]]; then
        echo "Error: Value exceeds max length ($max_len chars)" >&2
        return 1
    fi
    return 0
}

# Clean up expired keys
bb_cleanup_expired() {
    local db_path="$(_bb_get_db_path)"
    local now
    now=$(date +%s)

    sqlite3 "$db_path" "DELETE FROM kv WHERE expires_at > 0 AND expires_at < $now;"
}

# Set a value with schema validation
# Usage: blackboard_set_validated <key> <value>
blackboard_set_validated() {
    local key="$1"
    local value="$2"
    local schema_path="${3:-$BLACKBOARD_SCHEMA_PATH}"

    # Validate key
    if ! bb_validate_key "$key" "$schema_path"; then
        return 1
    fi

    # Validate value length
    if ! bb_validate_value_length "$value"; then
        return 1
    fi

    # Get TTL
    local ttl
    ttl=$(bb_get_ttl_for_key "$key" "$schema_path")

    # Calculate expiration time
    local expires_at=0
    if [[ "$ttl" -gt 0 ]]; then
        expires_at=$(( $(date +%s) + ttl ))
    fi

    # Ensure table exists and write
    _bb_ensure_table

    local db_path="$(_bb_get_db_path)"
    # Escape single quotes in value
    local escaped_value="${value//\'/\'\'}"
    local escaped_key="${key//\'/\'\'}"

    sqlite3 "$db_path" ".timeout 5000" \
        "INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES ('$escaped_key', '$escaped_value', $expires_at);"

    # Cleanup expired keys on write
    if [[ "${BLACKBOARD_TTL_CLEANUP_ON_WRITE:-true}" == "true" ]]; then
        bb_cleanup_expired
    fi
}

# Get a value with TTL cleanup
# Usage: blackboard_get <key>
blackboard_get() {
    local key="$1"
    local db_path="$(_bb_get_db_path)"

    if [[ ! -f "$db_path" ]]; then
        return 0
    fi

    # Ensure table exists
    _bb_ensure_table

    # Cleanup expired keys on read
    if [[ "${BLACKBOARD_TTL_CLEANUP_ON_READ:-true}" == "true" ]]; then
        bb_cleanup_expired
    fi

    # Escape single quotes in key
    local escaped_key="${key//\'/\'\'}"

    # Get value, checking expiration
    local now
    now=$(date +%s)
    sqlite3 "$db_path" ".timeout 5000" \
        "SELECT value FROM kv WHERE key = '$escaped_key' AND (expires_at = 0 OR expires_at > $now);"
}

# Atomic multi-key set (all-or-nothing via SQLite transaction)
# Usage: blackboard_atomic_set key1 value1 key2 value2 ...
# All keys are validated first. If any fails, none are set.
blackboard_atomic_set() {
    local schema_path="${BLACKBOARD_SCHEMA_PATH:-$PROJECT_ROOT/config/blackboard-schema.json}"
    local db_path="$(_bb_get_db_path)"
    local now
    now=$(date +%s)

    # Ensure table exists
    _bb_ensure_table

    # Parse key-value pairs into arrays
    local -a keys=()
    local -a values=()
    local -a ttls=()
    local idx=1

    while [[ $idx -le $# ]]; do
        local key="${!idx}"
        local next_idx=$((idx + 1))
        local value="${!next_idx:-}"

        # Validate key
        if ! bb_validate_key "$key" "$schema_path" 2>/dev/null; then
            return 1
        fi

        # Validate value length
        if ! bb_validate_value_length "$value" 2>/dev/null; then
            return 1
        fi

        keys+=("$key")
        values+=("$value")

        # Get TTL
        local ttl
        ttl=$(bb_get_ttl_for_key "$key" "$schema_path")
        local expires_at=0
        if [[ "$ttl" -gt 0 ]]; then
            expires_at=$(( now + ttl ))
        fi
        ttls+=("$expires_at")

        idx=$((idx + 2))
    done

    # All validations passed, now execute in a transaction
    local sql="BEGIN TRANSACTION;"
    for i in "${!keys[@]}"; do
        local escaped_key="${keys[$i]//\'/\'\'}"
        local escaped_value="${values[$i]//\'/\'\'}"
        sql+="INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES ('$escaped_key', '$escaped_value', ${ttls[$i]});"
    done
    sql+="COMMIT;"

    sqlite3 "$db_path" ".timeout 5000" "$sql"

    # Cleanup expired
    bb_cleanup_expired
}

# Get current timestamp in milliseconds
get_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date doesn't support %N, use perl or python
        if command -v perl >/dev/null 2>&1; then
            perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000'
        else
            python3 -c "import time; print(int(time.time() * 1000))"
        fi
    else
        date +%s%3N
    fi
}

start_heartbeat() {
    local tool_name="${1:-agent}"
    if [ -n "${HCOM_NAME:-}" ]; then
        # Health 2.0 Heartbeat
        # Updates status and reports metrics (latency, load) to the Blackboard.
        (
            while true; do
                # 1. Update hcom status (presence)
                hcom status --name "$HCOM_NAME" > /dev/null 2>&1 || true
                
                # 2. Measure latency (Blackboard round-trip)
                local start_time=$(get_ms)
                blackboard_get "fleet_health_${HCOM_NAME}" > /dev/null 2>&1 || true
                local end_time=$(get_ms)
                local latency=$((end_time - start_time))
                
                # 3. Report health metrics
                report_health "ready" "$latency" "0"
                
                sleep 20
            done
        ) &
        HEARTBEAT_PID=$!
        return 0
    fi
    return 1
}
