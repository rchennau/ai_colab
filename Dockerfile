# ai-colab Agent Dockerfile
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

# Install common LLM CLIs
RUN npm install -g @google/gemini-cli @anthropic-ai/claude-code qwen-cli

# Create working directory
WORKDIR /app

# Copy project files (can be overridden by volume)
COPY . /app

# Entrypoint: Start hcom relay and wait for commands
CMD ["hcom", "relay", "daemon", "start", "--foreground"]
