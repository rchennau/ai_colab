#!/usr/bin/env bash
# ai-colab Docker Entrypoint Script
# Handles first-run setup, configuration validation, and service startup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
APP_DIR="/app"
CONFIG_DIR="$APP_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.toml"
STATE_FILE="$APP_DIR/.ai-colab-state.json"
WEBUI_DIR="$APP_DIR/webui"
LOG_DIR="$APP_DIR/logs"

# Ensure directories exist
ensure_dirs() {
    mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/backups" "$CONFIG_DIR/profiles"
    mkdir -p "$LOG_DIR"
    mkdir -p "$HOME/.ai-colab"
}

# Logging functions
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}INFO${NC} $1"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}SUCCESS${NC} $1"
}

log_warn() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}WARN${NC} $1"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}ERROR${NC} $1" >&2
}

# Check if first run
is_first_run() {
    if [[ ! -f "$STATE_FILE" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        return 0
    fi
    return 1
}

# Initialize configuration from environment
init_config_from_env() {
    log_info "Initializing configuration from environment variables..."

    # Use config-manager for all operations
    local config_mgr="$APP_DIR/scripts/config-manager.sh"
    
    # Initialize state and config if missing
    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -f "$STATE_FILE" ]]; then
        log_info "Creating initial configuration..."
        bash "$config_mgr" init
        bash "$config_mgr" set version "1.0.0" false
        bash "$config_mgr" set installation.status "in-progress" false
        bash "$config_mgr" set installation.pathway "docker" false
        bash "$config_mgr" set docker.enabled "true" false
        bash "$config_mgr" set docker.image "ai-colab:latest" false
        bash "$config_mgr" set preferences.theme "dark" false
    fi

    # Apply environment overrides using config-manager
    if [[ -n "${COMPUTE_BACKEND:-}" ]]; then
        log_info "Setting compute backend: $COMPUTE_BACKEND"
        bash "$config_mgr" set compute.backend "$COMPUTE_BACKEND"
    fi

    # Add API keys to environment file and set in config if needed
    local env_file="$HOME/.ai-colab-env"
    touch "$env_file"
    
    if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
        echo "export NVIDIA_API_KEY=$NVIDIA_API_KEY" >> "$env_file"
        bash "$config_mgr" set compute.api_key_env "NVIDIA_API_KEY" false
        log_info "NVIDIA API key configured"
    fi

    if [[ -n "${RUNPOD_API_KEY:-}" ]]; then
        echo "export RUNPOD_API_KEY=$RUNPOD_API_KEY" >> "$env_file"
        log_info "RunPod API key configured"
    fi
    
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        echo "export GEMINI_API_KEY=$GEMINI_API_KEY" >> "$env_file"
        log_info "Gemini API key configured"
    fi

    log_success "Configuration initialized via config-manager"
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    local config_mgr="$APP_DIR/scripts/config-manager.sh"
    
    if ! bash "$config_mgr" validate; then
        log_error "Configuration validation failed"
        return 1
    fi

    log_success "Configuration validated"
    return 0
}

# Start Web UI
start_webui() {
    log_info "Starting Web UI server..."

    if [[ ! -d "$WEBUI_DIR" ]]; then
        log_warn "Web UI directory not found, creating basic structure..."
        mkdir -p "$WEBUI_DIR"
    fi

    # Check if Web UI app exists
    if [[ ! -f "$WEBUI_DIR/app.py" ]]; then
        log_warn "Web UI app not found, Web UI will be unavailable"
        log_info "Run the Web UI setup to enable the web interface"
        return 0
    fi

    # Start Flask app
    cd "$WEBUI_DIR"
    export FLASK_APP=app.py
    export FLASK_ENV=production

    log_info "Web UI starting on http://0.0.0.0:8080"

    # Use python3 to run the app with eventlet for WebSocket support
    python3 -c "
import eventlet
import eventlet.wsgi
from app import create_app

app = create_app()
eventlet.wsgi.server(eventlet.listen(('0.0.0.0', 8080)), app)
" &

    WEBUI_PID=$!
    echo "$WEBUI_PID" > /tmp/webui.pid

    log_success "Web UI started (PID: $WEBUI_PID)"
}

# Start API server (if separate from Web UI)
start_api() {
    log_info "Starting API server..."

    # For now, API is part of Web UI
    # In future versions, this could be a separate service
    log_info "API available at http://0.0.0.0:8081"
}

# Health check endpoint
health_check() {
    local status="healthy"
    local checks=()

    # Check Web UI
    if [[ -f /tmp/webui.pid ]] && kill -0 "$(cat /tmp/webui.pid)" 2>/dev/null; then
        checks+=("webui: ok")
    else
        checks+=("webui: not running")
        status="degraded"
    fi

    # Check configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        checks+=("config: ok")
    else
        checks+=("config: missing")
        status="degraded"
    fi

    # Output health status
    echo "{\"status\": \"$status\", \"checks\": [\"$(IFS='", "'; echo "${checks[*]}")\"]}"
}

# Show startup message
show_startup_message() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ai-colab Docker Container Started           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Web UI:${NC}  http://localhost:8080"
    echo -e "${BLUE}API:${NC}      http://localhost:8081"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  1. Open http://localhost:8080 in your browser"
    echo "  2. Complete the setup wizard"
    echo "  3. Launch agents from the dashboard"
    echo ""
    echo -e "${BLUE}Docker Commands:${NC}"
    echo "  View logs:     docker logs -f ai-colab"
    echo "  Stop:          docker-compose down"
    echo "  Restart:       docker-compose restart"
    echo "  Shell access:  docker exec -it ai-colab /bin/bash"
    echo ""
}

# Main entrypoint
main() {
    local mode="${1:-webui}"

    log_info "ai-colab Docker Entrypoint starting..."
    log_info "Mode: $mode"

    # Ensure directories
    ensure_dirs

    # Check first run
    if is_first_run; then
        log_info "First run detected, initializing..."
        init_config_from_env
    fi

    # Validate configuration
    validate_config || {
        log_error "Configuration validation failed"
        exit 1
    }

    # Handle different modes
    case "$mode" in
        webui)
            start_webui
            start_api
            show_startup_message

            # Keep container running and monitor services
            wait
            ;;

        cli)
            log_info "Starting in CLI mode..."
            exec /bin/bash
            ;;

        init)
            log_info "Initialization mode..."
            init_config_from_env
            log_success "Initialization complete"
            ;;

        health)
            health_check
            ;;

        *)
            log_error "Unknown mode: $mode"
            echo "Usage: entrypoint.sh [webui|cli|init|health]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
