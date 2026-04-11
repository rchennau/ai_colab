# ai-colab Agent Base Image
# Minimal environment for LLM-CLI agents

FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    python3 \
    python3-pip \
    ca-certificates \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast python package management
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install hcom client
RUN curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh

# Set working directory to the mapped project root
WORKDIR /workspace

# Default command
CMD ["bash"]
