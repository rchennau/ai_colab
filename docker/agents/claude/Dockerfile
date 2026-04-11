# ai-colab Claude Agent Image
FROM aicolab/agent-base:latest

# Install Claude Code CLI via npm
RUN npm install -g @anthropic-ai/claude-code

# Entrypoint script to handle hcom registration and tool launch
ENTRYPOINT ["hcom", "start", "--headless", "--as", "claude_worker", "--"]
CMD ["claude-code"]
