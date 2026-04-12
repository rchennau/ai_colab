#!/usr/bin/env bash
# ai-colab Agent Container Wrapper
# Handles hcom registration, heartbeat, and tool launch inside containers
# Usage: agent-wrapper.sh <tool_name> [args...]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TOOL="${1:-}"
shift || true

if [[ -z "$TOOL" ]]; then
    echo -e "${RED}Error: Tool name required${NC}"
    echo "Usage: agent-wrapper.sh <tool_name> [args...]"
    exit 1
fi

# Agent identity
AGENT_NAME="${HCOM_AGENT_NAME:-${TOOL}_worker_$(hostname)}"
export HCOM_NAME="$AGENT_NAME"

# MQTT/HCOM configuration
export HCOM_BROKER_URL="${HCOM_BROKER_URL:-mqtts://mqtt:8883}"
export HCOM_USERNAME="${HCOM_USERNAME:-ai-colab-admin}"
export HCOM_PASSWORD="${HCOM_PASSWORD:-}"

log_info() {
    echo -e "$(date '+%H:%M:%S') ${BLUE}INFO${NC} [$AGENT_NAME] $1"
}

log_success() {
    echo -e "$(date '+%H:%M:%S') ${GREEN}SUCCESS${NC} [$AGENT_NAME] $1"
}

log_error() {
    echo -e "$(date '+%H:%M:%S') ${RED}ERROR${NC} [$AGENT_NAME] $1" >&2
}

# Wait for MQTT broker to be ready
wait_for_mqtt() {
    local max_attempts=30
    local attempt=0

    log_info "Waiting for MQTT broker at $HCOM_BROKER_URL..."

    while [[ $attempt -lt $max_attempts ]]; do
        # Try to connect to MQTT broker
        if mosquitto_sub -h mqtt -p 8883 -t 'test' -C 1 -W 2 \
            --cafile /mosquitto/certs/ca.crt 2>/dev/null || \
           mosquitto_sub -h mqtt -p 8883 -t 'test' -C 1 -W 2 2>/dev/null; then
            log_success "MQTT broker is ready"
            return 0
        fi

        attempt=$((attempt + 1))
        sleep 2
    done

    log_error "MQTT broker not available after $((max_attempts * 2))s"
    return 1
}

# Register with hcom
register_hcom() {
    log_info "Registering with hcom as $AGENT_NAME..."

    if hcom start --as "$AGENT_NAME" --headless 2>/dev/null; then
        log_success "Registered with hcom"
        return 0
    else
        log_error "Failed to register with hcom"
        return 1
    fi
}

# Start heartbeat
start_heartbeat() {
    (
        while true; do
            hcom status --name "$HCOM_NAME" > /dev/null 2>&1 || true
            sleep 20
        done
    ) &
    HEARTBEAT_PID=$!
    log_info "Heartbeat started (PID: $HEARTBEAT_PID)"
}

# Cleanup on exit
cleanup() {
    log_info "Shutting down..."

    # Kill heartbeat
    if [[ -n "${HEARTBEAT_PID:-}" ]]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi

    # Deregister from hcom
    hcom stop --name "$HCOM_NAME" > /dev/null 2>&1 || true

    log_info "Shutdown complete"
}

trap cleanup EXIT

# ============================================================
# Main
# ============================================================

log_info "Starting $TOOL agent container..."

# Wait for MQTT broker
wait_for_mqtt || exit 1

# Register with hcom
register_hcom || exit 1

# Start heartbeat
start_heartbeat

# Find the tool
case "$TOOL" in
    gemini)
        if command -v gemini >/dev/null 2>&1; then
            CMD="gemini"
        elif command -v gemini-cli >/dev/null 2>&1; then
            CMD="gemini-cli"
        else
            log_error "Gemini CLI not found. Install with: pip3 install gemini-cli"
            exit 1
        fi
        ;;
    qwen)
        if command -v qwen-code >/dev/null 2>&1; then
            CMD="qwen-code"
        elif command -v qwen >/dev/null 2>&1; then
            CMD="qwen"
        else
            log_error "Qwen CLI not found. Install with: pip3 install qwen-code"
            exit 1
        fi
        ;;
    claude)
        if command -v claude-code >/dev/null 2>&1; then
            CMD="claude-code"
        elif command -v claude >/dev/null 2>&1; then
            CMD="claude"
        else
            log_error "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
            exit 1
        fi
        ;;
    deepseek)
        if command -v deepseek-cli >/dev/null 2>&1; then
            CMD="deepseek-cli"
        elif command -v deepseek >/dev/null 2>&1; then
            CMD="deepseek"
        else
            log_error "DeepSeek CLI not found"
            exit 1
        fi
        ;;
    *)
        CMD="$TOOL"
        ;;
esac

log_info "Launching $CMD..."

# Run the tool with remaining arguments
exec "$CMD" "$@"
