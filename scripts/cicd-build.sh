#!/usr/bin/env bash
# ai-colab CICD Build Script
# Builds the agent docker image.

set -euo pipefail

IMAGE_NAME=${1:-ai-colab-agent}
TAG=${2:-latest}

echo "Building Docker image: $IMAGE_NAME:$TAG"
docker build -t "$IMAGE_NAME:$TAG" .

echo "Build complete."
