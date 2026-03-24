#!/usr/bin/env bash
# ai-colab NVIDIA NIM Integration Script
# Configures local/remote agents to use NVIDIA NIM API.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

API_KEY=${NVIDIA_API_KEY:-}
if [[ -z "$API_KEY" ]]; then
    log_error "NVIDIA_API_KEY not set."
    exit 1
fi

log_info "Configuring NVIDIA NIM integration..."

# NVIDIA NIM endpoints typically follow this pattern
# We'll export a generic base URL that the agent wrapper can use
export COMPUTE_BASE_URL="https://integrate.api.nvidia.com/v1"

# Verify connectivity
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $API_KEY" "$COMPUTE_BASE_URL/models")

if [[ "$RESPONSE" == "200" ]]; then
    log_success "NVIDIA NIM connectivity verified."
    blackboard_set "compute_nvidia_status" "ready"
else
    log_error "Failed to connect to NVIDIA NIM (HTTP $RESPONSE)."
    exit 1
fi
