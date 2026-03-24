#!/usr/bin/env bash
# Terminal Detection Utility for ai-colab
# Detects terminal emulator and environment (iTerm2, WSL, etc.)
# and provides optimized configurations for each.

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Terminal detection results (exported for other scripts)
export AI_COLAB_TERMINAL=""
export AI_COLAB_ENVIRONMENT=""
export AI_COLAB_TMUX_CONFIG=""

# Detect if running in iTerm2
detect_iterm2() {
    # Check for iTerm2-specific environment variables
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]] || \
       [[ "$LC_TERMINAL" == "iTerm2" ]] || \
       [[ -n "$ITERM_SESSION_ID" ]]; then
        echo "iterm2"
        return 0
    fi
    
    # Check parent process for iTerm2 on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local parent_pid=$PPID
        local parent_cmd=""
        
        # Walk up the process tree to find the terminal
        for i in {1..5}; do
            if [[ -z "$parent_pid" ]] || [[ "$parent_pid" -eq 1 ]]; then
                break
            fi
            
            parent_cmd=$(ps -p "$parent_pid" -o comm= 2>/dev/null || echo "")
            
            if [[ "$parent_cmd" == *"iTerm"* ]] || [[ "$parent_cmd" == *"iterm"* ]]; then
                echo "iterm2"
                return 0
            fi
            
            parent_pid=$(ps -p "$parent_pid" -o ppid= 2>/dev/null | tr -d ' ')
        done
    fi
    
    return 1
}

# Detect if running in WSL/WSL2
detect_wsl() {
    # Check for WSL-specific indicators
    if [[ -f /proc/version ]]; then
        if grep -qi "microsoft" /proc/version 2>/dev/null; then
            echo "wsl"
            return 0
        fi
    fi
    
    # Check WSL_INTEROP (WSL2 specific)
    if [[ -n "$WSL_INTEROP" ]]; then
        echo "wsl2"
        return 0
    fi
    
    # Check for WSL distribution name
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        echo "wsl"
        return 0
    fi
    
    return 1
}

# Detect Windows Terminal (when running in WSL)
detect_windows_terminal() {
    if [[ -n "$WT_SESSION" ]] || [[ -n "$WT_PROFILE_ID" ]]; then
        echo "windows_terminal"
        return 0
    fi
    return 1
}

# Detect macOS Terminal.app
detect_terminal_app() {
    if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
        echo "terminal_app"
        return 0
    fi
    return 1
}

# Detect VS Code integrated terminal
detect_vscode_terminal() {
    if [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$VSCODE_INJECTION" ]]; then
        echo "vscode"
        return 0
    fi
    return 1
}

# Main detection function
detect_terminal() {
    local terminal=""
    local environment=""
    
    # First detect environment
    if detect_wsl > /dev/null 2>&1; then
        environment="wsl"
        
        # Then detect terminal within WSL
        if detect_windows_terminal > /dev/null 2>&1; then
            terminal="windows_terminal"
        else
            terminal="wsl_default"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        environment="macos"
        
        # Detect macOS terminal
        if detect_iterm2 > /dev/null 2>&1; then
            terminal="iterm2"
        elif detect_terminal_app > /dev/null 2>&1; then
            terminal="terminal_app"
        elif detect_vscode_terminal > /dev/null 2>&1; then
            terminal="vscode"
        else
            terminal="macos_unknown"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        environment="linux"
        
        if detect_vscode_terminal > /dev/null 2>&1; then
            terminal="vscode"
        elif detect_iterm2 > /dev/null 2>&1; then
            terminal="iterm2"
        else
            terminal="linux_unknown"
        fi
    else
        environment="unknown"
        terminal="unknown"
    fi
    
    # Export results
    export AI_COLAB_TERMINAL="$terminal"
    export AI_COLAB_ENVIRONMENT="$environment"
    
    echo "$terminal:$environment"
}

# Get optimized tmux config path for current terminal
get_tmux_config() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(dirname "$script_dir")"
    
    case "$AI_COLAB_TERMINAL" in
        iterm2)
            echo "$project_root/config/tmux.iterm2.conf"
            ;;
        windows_terminal)
            echo "$project_root/config/tmux.windows-terminal.conf"
            ;;
        vscode)
            echo "$project_root/config/tmux.vscode.conf"
            ;;
        *)
            echo "$project_root/config/tmux.default.conf"
            ;;
    esac
}

# Print terminal info for debugging
print_terminal_info() {
    echo -e "${BLUE}=== Terminal Detection Results ===${NC}"
    echo -e "Terminal:        ${GREEN}$AI_COLAB_TERMINAL${NC}"
    echo -e "Environment:     ${GREEN}$AI_COLAB_ENVIRONMENT${NC}"
    
    if [[ "$AI_COLAB_TERMINAL" == "iterm2" ]]; then
        echo -e "Optimizations:   ${GREEN}iTerm2-specific enabled${NC}"
        echo -e "  - Shell integration: Available"
        echo -e "  - Unicode support:   Full"
        echo -e "  - True color:        Enabled"
        echo -e "  - Ligatures:         Supported"
    elif [[ "$AI_COLAB_ENVIRONMENT" == "wsl" ]]; then
        echo -e "Optimizations:   ${GREEN}WSL-specific enabled${NC}"
        echo -e "  - Windows interop:   Enabled"
        echo -e "  - Path translation:  Available"
        if [[ "$AI_COLAB_TERMINAL" == "windows_terminal" ]]; then
            echo -e "  - Terminal:          Windows Terminal"
        fi
    fi
    echo ""
}

# Apply terminal-specific optimizations
apply_optimizations() {
    case "$AI_COLAB_TERMINAL" in
        iterm2)
            # iTerm2-specific optimizations
            export COLORTERM="truecolor"
            export TERM="xterm-256color"
            
            # Enable iTerm2 shell integration if available
            if [[ -f "$HOME/.iterm2_shell_integration.bash" ]]; then
                source "$HOME/.iterm2_shell_integration.bash" 2>/dev/null || true
            fi
            ;;
        windows_terminal)
            # Windows Terminal optimizations
            export COLORTERM="truecolor"
            export TERM="xterm-256color"
            
            # Fix line ending issues
            export GIT_CRLF="false"
            ;;
        vscode)
            # VS Code terminal optimizations
            export COLORTERM="truecolor"
            export TERM="xterm-256color"
            ;;
    esac
    
    # WSL-specific optimizations
    if [[ "$AI_COLAB_ENVIRONMENT" == "wsl" ]]; then
        # Enable Windows interop
        export WSLENV="WT_SESSION:WT_PROFILE_ID:PATH/up"
        
        # Set Windows path for interop
        if command -v wslpath &>/dev/null; then
            export WINDOWS_PATH="$(wslpath -w "$HOME" 2>/dev/null || echo "C:\\Users")"
        fi
    fi
}

# Initialize terminal detection (call this from other scripts)
init_terminal() {
    detect_terminal > /dev/null
    apply_optimizations
}

# If run directly, print info
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_terminal
    print_terminal_info
    
    echo -e "${BLUE}=== Environment Variables ===${NC}"
    echo "AI_COLAB_TERMINAL=$AI_COLAB_TERMINAL"
    echo "AI_COLAB_ENVIRONMENT=$AI_COLAB_ENVIRONMENT"
    echo ""
    
    config_path=$(get_tmux_config)
    echo -e "${BLUE}=== Recommended tmux Config ===${NC}"
    echo "Path: $config_path"
    if [[ -f "$config_path" ]]; then
        echo -e "Status: ${GREEN}Found${NC}"
    else
        echo -e "Status: ${YELLOW}Not found (will use defaults)${NC}"
    fi
fi
