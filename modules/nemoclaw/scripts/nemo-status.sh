#!/usr/bin/env bash
# NeMo-Claude Health Check
# Verifies NVIDIA NIM API connectivity and model availability.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

# Sourcing environment if available
[ -f "$HOME/.ai-colab-env" ] && source "$HOME/.ai-colab-env"

API_KEY=${NVIDIA_API_KEY:-}
if [[ -z "$API_KEY" ]]; then
    # Try .zshrc_secrets for testing as per user request
    if [ -f "$HOME/.zshrc_secrets" ]; then
        API_KEY=$(grep "NVIDIA_API_KEY" "$HOME/.zshrc_secrets" | cut -d'"' -f2 || echo "")
    fi
fi

if [[ -z "$API_KEY" ]]; then
    echo "Error: NVIDIA_API_KEY not found."
    exit 1
fi

log_info "Checking NVIDIA NIM API health..."

BASE_URL="https://integrate.api.nvidia.com/v1"
START_TIME=$(date +%s%N)
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $API_KEY" "$BASE_URL/models")
END_TIME=$(date +%s%N)

LATENCY=$(( (END_TIME - START_TIME) / 1000000 )) # ms

if [[ "$RESPONSE" == "200" ]]; then
    log_success "NVIDIA NIM is online. Latency: ${LATENCY}ms."
    hcom send -- "NVIDIA NIM Status: [ONLINE] Latency: ${LATENCY}ms."
else
    log_error "NVIDIA NIM returned HTTP $RESPONSE."
    hcom send -- "NVIDIA NIM Status: [OFFLINE] HTTP $RESPONSE."
fi
