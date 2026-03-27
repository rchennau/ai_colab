#!/usr/bin/env bash
# ai-colab Centralized Logging Utility
# Provides consistent logging across all scripts with levels, formatting, and rotation

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_CRITICAL=4

# Default log level (can be overridden by environment)
AI_COLAB_LOG_LEVEL="${AI_COLAB_LOG_LEVEL:-1}"

# Log file location
AI_COLAB_LOG_FILE="${AI_COLAB_LOG_FILE:-$HOME/.ai-colab/ai-colab.log}"
LOG_DIR="$(dirname "$AI_COLAB_LOG_FILE")"

# Ensure log directory exists
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Colors for console output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m' # No Color

# Get current timestamp in ISO format
get_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

# Get process ID and name
get_process_info() {
    echo "$$:${BASH_SOURCE[1]:-script}"
}

# Internal log function
_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local message="$4"
    local timestamp=$(get_timestamp)
    local process=$(get_process_info)
    
    # Check if we should log at this level
    if [[ $level_num -lt $AI_COLAB_LOG_LEVEL ]]; then
        return 0
    fi
    
    # Format log line
    local log_line="[$timestamp] [$level] [$process] $message"
    
    # Write to log file
    echo "$log_line" >> "$AI_COLAB_LOG_FILE" 2>/dev/null || true
    
    # Write to console (with colors)
    case $level in
        DEBUG)
            echo -e "${COLOR_CYAN}DEBUG:${COLOR_NC} $message" >&2
            ;;
        INFO)
            echo -e "${COLOR_GREEN}INFO:${COLOR_NC} $message" >&2
            ;;
        WARN)
            echo -e "${COLOR_YELLOW}WARN:${COLOR_NC} $message" >&2
            ;;
        ERROR)
            echo -e "${COLOR_RED}ERROR:${COLOR_NC} $message" >&2
            ;;
        CRITICAL)
            echo -e "${COLOR_RED}CRITICAL:${COLOR_NC} $message" >&2
            ;;
    esac
}

# Public logging functions
log_debug() {
    _log "DEBUG" "$LOG_LEVEL_DEBUG" "$COLOR_CYAN" "$*"
}

log_info() {
    _log "INFO" "$LOG_LEVEL_INFO" "$COLOR_GREEN" "$*"
}

log_warn() {
    _log "WARN" "$LOG_LEVEL_WARN" "$COLOR_YELLOW" "$*"
}

log_error() {
    _log "ERROR" "$LOG_LEVEL_ERROR" "$COLOR_RED" "$*"
}

log_critical() {
    _log "CRITICAL" "$LOG_LEVEL_CRITICAL" "$COLOR_RED" "$*"
}

# Log function with timing
log_timing() {
    local operation="$1"
    local start_time="$2"
    local end_time="${3:-$(date +%s.%N)}"
    
    if [[ -n "$start_time" ]]; then
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        log_info "Operation '$operation' completed in ${duration}s"
    fi
}

# Log security events (always logged regardless of level)
log_security() {
    local event="$1"
    local details="$2"
    local timestamp=$(get_timestamp)
    local process=$(get_process_info)
    
    local log_line="[$timestamp] [SECURITY] [$process] $event: $details"
    
    # Always write security events to log
    echo "$log_line" >> "$AI_COLAB_LOG_FILE" 2>/dev/null || true
    
    # Also write to a dedicated security log
    local security_log="$LOG_DIR/security.log"
    echo "$log_line" >> "$security_log" 2>/dev/null || true
    
    # Alert to console
    echo -e "${COLOR_RED}SECURITY:${COLOR_NC} $event" >&2
}

# Log API requests (for Web UI and API endpoints)
log_api_request() {
    local method="$1"
    local endpoint="$2"
    local status="$3"
    local duration="$4"
    local client_ip="${5:-unknown}"
    
    local timestamp=$(get_timestamp)
    local log_line="[$timestamp] [API] $method $endpoint -> $status (${duration}ms) from $client_ip"
    
    echo "$log_line" >> "$AI_COLAB_LOG_FILE" 2>/dev/null || true
    
    # Also write to API log
    local api_log="$LOG_DIR/api.log"
    echo "$log_line" >> "$api_log" 2>/dev/null || true
}

# Rotate log files
rotate_logs() {
    local max_size="${1:-10485760}"  # Default 10MB
    local max_files="${2:-5}"
    
    if [[ -f "$AI_COLAB_LOG_FILE" ]]; then
        local size=$(stat -f%z "$AI_COLAB_LOG_FILE" 2>/dev/null || stat -c%s "$AI_COLAB_LOG_FILE" 2>/dev/null || echo 0)
        
        if [[ $size -gt $max_size ]]; then
            log_info "Rotating log file (size: $size bytes)"
            
            # Rotate existing logs
            for i in $(seq $((max_files - 1)) -1 1); do
                if [[ -f "${AI_COLAB_LOG_FILE}.$i" ]]; then
                    mv "${AI_COLAB_LOG_FILE}.$i" "${AI_COLAB_LOG_FILE}.$((i + 1))"
                fi
            done
            
            # Move current log
            mv "$AI_COLAB_LOG_FILE" "${AI_COLAB_LOG_FILE}.1"
            
            # Create new log file
            touch "$AI_COLAB_LOG_FILE"
            
            log_info "Log rotation complete"
        fi
    fi
}

# Get log statistics
get_log_stats() {
    local timestamp=$(get_timestamp)
    
    echo "=== Log Statistics (as of $timestamp) ==="
    echo ""
    
    if [[ -f "$AI_COLAB_LOG_FILE" ]]; then
        local total_lines=$(wc -l < "$AI_COLAB_LOG_FILE")
        local error_count=$(grep -c "\[ERROR\]" "$AI_COLAB_LOG_FILE" 2>/dev/null || echo 0)
        local warn_count=$(grep -c "\[WARN\]" "$AI_COLAB_LOG_FILE" 2>/dev/null || echo 0)
        local security_count=$(grep -c "\[SECURITY\]" "$LOG_DIR/security.log" 2>/dev/null || echo 0)
        local file_size=$(stat -f%z "$AI_COLAB_LOG_FILE" 2>/dev/null || stat -c%s "$AI_COLAB_LOG_FILE" 2>/dev/null || echo 0)
        
        echo "Main Log: $AI_COLAB_LOG_FILE"
        echo "  Size: $file_size bytes"
        echo "  Total Lines: $total_lines"
        echo "  Errors: $error_count"
        echo "  Warnings: $warn_count"
        echo ""
        
        if [[ -f "$LOG_DIR/security.log" ]]; then
            echo "Security Log: $LOG_DIR/security.log"
            echo "  Security Events: $security_count"
            echo ""
        fi
        
        if [[ -f "$LOG_DIR/api.log" ]]; then
            local api_count=$(wc -l < "$LOG_DIR/api.log")
            echo "API Log: $LOG_DIR/api.log"
            echo "  API Requests: $api_count"
            echo ""
        fi
    else
        echo "No log file found at: $AI_COLAB_LOG_FILE"
    fi
}

# Initialize logging (call at script start)
init_logging() {
    local script_name="${1:-$(basename "$0")}"
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    # Touch log file
    touch "$AI_COLAB_LOG_FILE" 2>/dev/null || true
    
    # Set secure permissions
    chmod 600 "$AI_COLAB_LOG_FILE" 2>/dev/null || true
    chmod 700 "$LOG_DIR" 2>/dev/null || true
    
    # Rotate logs if needed
    rotate_logs
    
    log_info "Logging initialized for $script_name (level: $AI_COLAB_LOG_LEVEL)"
}

# Export functions for use in other scripts
export -f log_debug log_info log_warn log_error log_critical
export -f log_timing log_security log_api_request
export -f rotate_logs get_log_stats init_logging
export -f get_timestamp get_process_info _log
