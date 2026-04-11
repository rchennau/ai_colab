#!/usr/bin/env bash
# ai-colab Agent Image Builder
# Builds all specialized agent Docker images

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker/agents"

build_image() {
    local name="$1"
    local path="$2"
    local tag="aicolab/agent-${name}:latest"
    
    echo -e "${BLUE}▶ Building $tag...${NC}"
    if docker build -t "$tag" "$path"; then
        echo -e "  ${GREEN}✓ Success${NC}"
    else
        echo -e "  ${RED}✗ Failed${NC}"
        return 1
    fi
}

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ai-colab Agent Image Builder           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

# Check for docker
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: docker command not found.${NC}"
    exit 1
fi

# 1. Build Base Image First
build_image "base" "$DOCKER_DIR/base"

# 2. Build Specific Agents
for agent_dir in "$DOCKER_DIR"/*/; do
    agent_name=$(basename "$agent_dir")
    if [[ "$agent_name" != "base" ]]; then
        build_image "$agent_name" "$agent_dir"
    fi
done

echo -e "\n${GREEN}✓ All agent images processed.${NC}"
