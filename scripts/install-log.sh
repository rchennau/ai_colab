#!/usr/bin/env bash
# ai-colab Standard Logging Utility
# Provides consistent logging to file for installation and launch processes.

# Determine standard Linux log directory (XDG_STATE_HOME or ~/.local/state)
LOG_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/ai-colab"
mkdir -p "$LOG_BASE"

# Get canonical log file path
get_log_file() {
    local component="${1:-system}"
    echo "$LOG_BASE/${component}.log"
}

# Log a message with timestamp and level
# Usage: log_to_file <component> <level> <message>
log_to_file() {
    local component="$1"
    local level="$2"
    local message="$3"
    local log_file=$(get_log_file "$component")
    
    # Create log file with secure permissions if it doesn't exist
    if [[ ! -f "$log_file" ]]; then
        touch "$log_file"
        chmod 600 "$log_file"
    fi
    
    printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$log_file"
}

# Convenience wrappers
log_install_info() { log_to_file "install" "INFO" "$1"; }
log_install_error() { log_to_file "install" "ERROR" "$1"; }
log_launch_info() { log_to_file "launch" "INFO" "$1"; }
log_launch_error() { log_to_file "launch" "ERROR" "$1"; }

# If executed directly, show where logs are
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ai-colab Logs Directory: $LOG_BASE"
    echo "Install Log: $(get_log_file install)"
    echo "Launch Log:  $(get_log_file launch)"
fi
