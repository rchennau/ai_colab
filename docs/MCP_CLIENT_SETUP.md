# MCP Client Configuration Templates

Configuration templates for integrating LLM-CLIs with the ai-colab MCP server.

## Quick Start

1. **Install MCP dependencies:**
   ```bash
   pip install -r requirements-mcp.txt
   ```

2. **Test MCP server:**
   ```bash
   python -m mcp.ai_colab_server
   ```

3. **Configure your LLM-CLI** (see below)

---

## gemini-cli Configuration

**Location:** `~/.gemini-cli/config.toml`

```toml
# ai-colab MCP Server Integration
[mcp]
enabled = true

[mcp.servers.ai-colab]
name = "ai-colab"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
transport = "stdio"
working_directory = "/Users/rchennault/Library/Mobile Documents/com~apple~CloudDocs/GitHub/ai_colab"
timeout = 30000
env = {}

# Optional: Enable specific tools
[mcp.servers.ai-colab.tools]
blackboard_get = true
blackboard_set = true
tracks_read = true
tracks_update = true
kb_search = true
kb_index = true
kb_stats = true
agent_spawn = true
agent_list = true
git_sync = true
build_trigger = true
health_check = true
```

**Usage Examples:**

```
@ai-colab What's the current project status?
@ai-colab Search the knowledge base for "blackboard architecture"
@ai-colab Update task "Phase 2.1" to completed
```

---

## qwen-code Configuration

**Location:** `~/.qwen/config.toml`

```toml
# ai-colab MCP Server Integration
[mcp]
enabled = true

[mcp.servers.ai-colab]
name = "ai-colab"
type = "stdio"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
cwd = "/Users/rchennault/Library/Mobile Documents/com~apple~CloudDocs/GitHub/ai_colab"

# Optional: SSE transport (requires server running)
# [mcp.servers.ai-colab]
# name = "ai-colab"
# type = "sse"
# endpoint = "http://localhost:8765/sse"
```

---

## claude-code Configuration

**Location:** `~/.claude/settings.json` or project `.claude/settings.local.json`

```json
{
  "mcpServers": {
    "ai-colab": {
      "command": "python",
      "args": ["-m", "mcp.ai_colab_server"],
      "cwd": "/Users/rchennault/Library/Mobile Documents/com~apple~CloudDocs/GitHub/ai_colab",
      "transportType": "stdio"
    }
  }
}
```

---

## Manual Testing

Test MCP server directly:

```bash
# Start server
python -m mcp.ai_colab_server

# In another terminal, test via stdio
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python -m mcp.ai_colab_server
```

---

## Troubleshooting

### Server won't start

1. Check dependencies: `pip install -r requirements-mcp.txt`
2. Verify path: `cd /path/to/ai_colab`
3. Check logs: Look for error messages

### Tools not appearing

1. Verify server is running
2. Check tool names in configuration
3. Restart LLM-CLI

### Connection timeout

1. Increase timeout in config
2. Check if server process is alive
3. Verify working directory is correct

---

## Available Tools

| Tool | Description | Example |
|------|-------------|---------|
| `blackboard_get` | Get KV store value | "Get the current task from blackboard" |
| `blackboard_set` | Set KV store value | "Store this result in the blackboard" |
| `tracks_read` | Read project tracks | "What's the project status?" |
| `tracks_update` | Update task status | "Mark Phase 2.1 as complete" |
| `kb_search` | Search knowledge base | "Find docs about MCP architecture" |
| `kb_index` | Trigger indexing | "Re-index the knowledge base" |
| `kb_stats` | Get index stats | "How many documents are indexed?" |
| `agent_spawn` | Spawn remote agent | "Spawn a reviewer agent" |
| `agent_list` | List active agents | "Which agents are running?" |
| `git_sync` | Sync git repository | "Pull latest changes" |
| `build_trigger` | Trigger build | "Run the build" |
| `health_check` | Check system health | "Is the system healthy?" |
