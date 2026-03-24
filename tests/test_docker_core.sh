#!/usr/bin/env bash
# Test Harness for ai-colab Orchestration Core Docker Build
# Verifies that the Hub container builds, starts, and runs the core services.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

IMAGE_NAME="ai-colab-core-test"
CONTAINER_NAME="ai-colab-core-verify"
TEST_PORT=5051 # Use different port than default to avoid conflicts

log_info() { echo -e "${BLUE}[$(date +%T)] INFO:${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +%T)] SUCCESS:${NC} $1"; }
log_error() { echo -e "${RED}[$(date +%T)] ERROR:${NC} $1"; }

# 1. Prerequisite Checks
log_info "Starting Docker build verification..."
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not in PATH."
    exit 1
fi

# 2. Build the Image
log_info "Building core image..."
if ! bash scripts/cicd-build.sh "$IMAGE_NAME" "latest" > /tmp/docker_build.log 2>&1; then
    log_error "Docker build failed. See /tmp/docker_build.log for details."
    exit 1
fi
log_success "Docker build successful."

# 3. Start the Container
log_info "Starting container..."
# Ensure any old container is gone
docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true

docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$TEST_PORT:5050" \
    "$IMAGE_NAME:latest"

# Wait for services to initialize
log_info "Waiting for services to initialize (5s)..."
sleep 5

# 4. Verify Services
log_info "Verifying core services..."

# Check if hcom relay is running inside
if ! docker exec "$CONTAINER_NAME" pgrep -f "hcom relay" > /dev/null; then
    log_error "hcom relay daemon is not running inside the container."
    docker logs "$CONTAINER_NAME"
    exit 1
fi
log_success "hcom relay is alive."

# Check if web dashboard is listening
if ! docker exec "$CONTAINER_NAME" pgrep -f "hcom-web-dashboard.py" > /dev/null; then
    log_error "Web dashboard backend is not running inside the container."
    exit 1
fi
log_success "Web dashboard is alive."

# Check if Conductor scripts are present
if ! docker exec "$CONTAINER_NAME" ls scripts/conductor-workflow.sh > /dev/null; then
    log_error "Conductor scripts are missing from the container."
    exit 1
fi
log_success "Filesystem integrity verified."

# 5. Connectivity Test (Simple curl to Flask API)
log_info "Testing API connectivity..."
if ! curl -s "http://localhost:$TEST_PORT/api/events" > /dev/null; then
    log_error "Failed to connect to web dashboard API on port $TEST_PORT."
    exit 1
fi
log_success "API connectivity confirmed."

# 6. Cleanup
log_info "Cleaning up..."
docker stop "$CONTAINER_NAME" > /dev/null
docker rm "$CONTAINER_NAME" > /dev/null
docker rmi "$IMAGE_NAME:latest" > /dev/null

log_success "========================================="
log_success "  Docker Core Verification PASSED! 🚀"
log_success "========================================="
