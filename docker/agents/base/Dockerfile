# ai-colab Agent Base Image
# Minimal environment for LLM-CLI agents with hcom integration

FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PROJECT_ROOT=/workspace
ENV HCOM_BROKER_URL=mqtts://mqtt:8883
ENV HCOM_USERNAME=ai-colab-admin
ENV HCOM_PASSWORD=

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    git \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    nodejs \
    npm \
    tmux \
    sqlite3 \
    jq \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install uv for fast python package management
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install hcom client
RUN curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh

# Create agent user
RUN useradd -m -s /bin/bash agent && \
    mkdir -p /workspace /home/agent/.hcom && \
    chown -R agent:agent /workspace /home/agent/.hcom

# Set working directory
WORKDIR /workspace

# Copy agent wrapper script (will be mounted from host or built into agent-specific images)
COPY docker/agents/agent-wrapper.sh /usr/local/bin/agent-wrapper.sh
RUN chmod +x /usr/local/bin/agent-wrapper.sh

# Default command - will be overridden by agent-specific Dockerfiles
CMD ["bash"]
