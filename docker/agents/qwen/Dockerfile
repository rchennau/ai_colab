# ai-colab Qwen Agent Image
FROM aicolab/agent-base:latest

# Install Qwen CLI (via uv for fast installation)
RUN uv pip install qwen-code --system 2>/dev/null || \
    pip3 install --break-system-packages qwen-code 2>/dev/null || true

# Entrypoint uses agent wrapper
ENTRYPOINT ["/usr/local/bin/agent-wrapper.sh", "qwen"]
CMD []
