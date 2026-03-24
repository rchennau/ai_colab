#!/usr/bin/env bash
# ai-colab CICD Build Script
# Builds the unified self-hosted environment container image.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker not found. Please install Docker to use this script."
    exit 1
fi

IMAGE_NAME=${1:-ai-colab-unified}
TAG=${2:-latest}

echo "Building Unified Self-Hosted Image: $IMAGE_NAME:$TAG"
docker build -t "$IMAGE_NAME:$TAG" .

echo "Build complete."
