# ai-colab Gemini Agent Image
FROM aicolab/agent-base:latest

# Install Gemini CLI
RUN pip3 install --break-system-packages gemini-cli

# Set environment for Google Auth if provided
ENV GOOGLE_APPLICATION_CREDENTIALS=/workspace/.google-auth.json

# Entrypoint script to handle hcom registration and tool launch
ENTRYPOINT ["hcom", "start", "--headless", "--as", "gemini_worker", "--"]
CMD ["gemini"]
