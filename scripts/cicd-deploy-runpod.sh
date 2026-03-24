#!/usr/bin/env bash
# ai-colab Cloud Deployment Script (RunPod)
# Self-hosts the unified ai-colab environment on a RunPod instance.

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

API_KEY=${RUNPOD_API_KEY:-}
if [[ -z "$API_KEY" ]]; then
    log_error "RUNPOD_API_KEY not set."
    exit 1
fi

IMAGE_NAME=${1:-ai-colab-unified:latest}
GPU_TYPE=${2:-"NVIDIA GeForce RTX 3090"}

log_info "Self-hosting ai-colab on RunPod ($GPU_TYPE)..."

# Construct GraphQL mutation
QUERY="mutation {
  podFindAndDeployOnGpu(
    input: {
      gpuTypeId: \"$GPU_TYPE\",
      gpuCount: 1,
      imageName: \"$IMAGE_NAME\",
      dockerArgs: \"hcom relay daemon start --foreground\",
      containerDiskInGb: 20,
      volumeInGb: 20,
      env: [
        { key: \"NVIDIA_API_KEY\", value: \"${NVIDIA_API_KEY:-}\" },
        { key: \"HCOM_RELAY_HOST\", value: \"$(hostname -I | awk '{print $1}')\" }
      ]
    }
  ) {
    id
    imageName
    machineId
  }
}"

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $API_KEY" \
    -d "{\"query\": \"$QUERY\"}" https://api.runpod.io/graphql)

POD_ID=$(echo "$RESPONSE" | grep -oP '"id": "\K[^"]+' | head -n 1 || echo "")

if [[ -n "$POD_ID" ]]; then
    log_success "Pod deployed! ID: $POD_ID"
    blackboard_set "fleet_remote_pod_$POD_ID" "active"
else
    log_error "Deployment failed: $RESPONSE"
    exit 1
fi
