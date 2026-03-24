# ai-colab Orchestration Core Dockerfile
# This container hosts the 'Hub' (hcom relay, Conductor, Blackboard, and Web UI).
# Agents and LLM models run OUTSIDE this container and connect via remote CLIs.
FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies for orchestration
RUN apt-get update && apt-get install -y \
    bash curl git tmux sqlite3 python3 python3-pip \
    nodejs npm build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies for the web dashboard
RUN python3 -m pip install --break-system-packages flask

# Install hcom (Messaging backbone)
RUN curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install LLM Remote Connectors (Clients only)
# These allow the Conductor to call remote models (Gemini, Claude, Qwen, etc.)
RUN npm install -g @google/gemini-cli @anthropic-ai/claude-code @qwen-code/qwen-code

# Create working directory
WORKDIR /app

# Copy orchestration scripts and modules
COPY . /app

# Ensure hcom config is in the expected location
RUN mkdir -p /root/.hcom && ln -s /app/config.toml /root/.hcom/config.toml

# The core is self-hosted and acts as a controller for remote agents.
# Entrypoint starts the hcom relay and the web dashboard backend.
CMD ["bash", "-c", "hcom relay daemon start && python3 scripts/hcom-web-dashboard.py & sleep 2 && hcom relay daemon status && tail -f /dev/null"]
