# ai-colab Unified Environment Dockerfile
# Supports local self-hosting or deployment to Docker-compatible clouds (AWS, GCP, RunPod).
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash curl git tmux sqlite3 python3 python3-pip \
    nodejs npm build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install hcom
RUN curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install LLM CLIs
RUN npm install -g @google/gemini-cli @anthropic-ai/claude-code qwen-cli

# Create working directory
WORKDIR /app

# Copy project files
COPY . /app

# The container is designed for self-hosting. 
# Use './launch.sh' inside the container to start the interactive dashboard.
CMD ["bash", "-c", "hcom relay daemon start && tail -f /dev/null"]
