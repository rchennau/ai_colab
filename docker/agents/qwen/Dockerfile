# ai-colab Qwen Agent Image
FROM aicolab/agent-base:latest

# Install Qwen Agent CLI
RUN pip3 install --break-system-packages qwen-agent

# Entrypoint script to handle hcom registration and tool launch
ENTRYPOINT ["hcom", "start", "--headless", "--as", "qwen_worker", "--"]
CMD ["qwen-code"]
