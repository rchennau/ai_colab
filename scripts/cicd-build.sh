#!/usr/bin/env bash
# ai-colab CICD Build Script
# Builds the Orchestration Core (Hub) container image.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker not found. Please install Docker to use this script."
    exit 1
fi

IMAGE_NAME=${1:-ai-colab-core}
TAG=${2:-latest}

echo "Building ai-colab Orchestration Core Image: $IMAGE_NAME:$TAG"
docker build -t "$IMAGE_NAME:$TAG" .

echo "Build complete."
