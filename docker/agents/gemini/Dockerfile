# ai-colab Gemini Agent Image
FROM aicolab/agent-base:latest

# Install Gemini CLI
RUN pip3 install --break-system-packages google-genai 2>/dev/null || \
    npm install -g @anthropic-ai/claude-code 2>/dev/null || true

# Google Auth support
RUN pip3 install --break-system-packages google-auth 2>/dev/null || true

# Set environment for Google Auth if provided
ENV GOOGLE_APPLICATION_CREDENTIALS=/workspace/.google-auth.json

# Entrypoint uses agent wrapper
ENTRYPOINT ["/usr/local/bin/agent-wrapper.sh", "gemini"]
CMD []
