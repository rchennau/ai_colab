# ai-colab Docker Image
# Multi-agent development environment with Web UI support

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Metadata
LABEL maintainer="ai-colab team"
LABEL version="2.0.0"
LABEL description="Multi-agent development environment with Web UI"

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV NODE_ENV=production

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    bash \
    curl \
    wget \
    git \
    tmux \
    sqlite3 \
    ca-certificates \
    gnupg \
    lsb-release \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Node.js (for LLM CLIs)
    nodejs \
    npm \
    # Additional tools
    jq \
    vim \
    less \
    htop \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install hcom
RUN curl -fsSL https://raw.githubusercontent.com/aannoo/hcom/main/install.sh | sh

# Create non-root user for security
RUN useradd -m -s /bin/bash ai-colab && \
    mkdir -p /home/ai-colab/.ai-colab && \
    chown -R ai-colab:ai-colab /home/ai-colab

# Set working directory
WORKDIR /app

# Copy project files
COPY --chown=ai-colab:ai-colab . /app/

# Install Python dependencies for Web UI
COPY requirements-webui.txt /tmp/requirements.txt
RUN pip3 install --break-system-packages -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Create directories for persistence
RUN mkdir -p /app/config \
    /app/config/backups \
    /app/config/profiles \
    /app/modules \
    /app/.ai-colab-backup \
    && chown -R ai-colab:ai-colab /app

# Copy entrypoint script
COPY --chown=ai-colab:ai-colab docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER ai-colab

# Expose ports
# 8080: Web UI
# 8081: API
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["webui"]
