# ai-colab DeepSeek Agent Image
FROM aicolab/agent-base:latest

# Install DeepSeek CLI
RUN pip3 install --break-system-packages deepseek-cli 2>/dev/null || \
    npm install -g deepseek-cli 2>/dev/null || true

# Entrypoint uses agent wrapper
ENTRYPOINT ["/usr/local/bin/agent-wrapper.sh", "deepseek"]
CMD []
