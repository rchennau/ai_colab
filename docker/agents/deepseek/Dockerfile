# ai-colab DeepSeek Agent Image
FROM aicolab/agent-base:latest

# Install DeepSeek CLI (assuming a python package exists or mock)
RUN pip3 install --break-system-packages deepseek-cli

# Entrypoint script to handle hcom registration and tool launch
ENTRYPOINT ["hcom", "start", "--headless", "--as", "deepseek_worker", "--"]
CMD ["deepseek"]
