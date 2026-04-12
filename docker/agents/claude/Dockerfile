# ai-colab Claude Agent Image
FROM aicolab/agent-base:latest

# Install Claude CLI
RUN npm install -g @anthropic-ai/claude-code 2>/dev/null || \
    pip3 install --break-system-packages claude-code 2>/dev/null || true

# Entrypoint uses agent wrapper
ENTRYPOINT ["/usr/local/bin/agent-wrapper.sh", "claude"]
CMD []
