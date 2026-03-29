# Web Terminal & Debug Mode Guide

## Overview

ai-colab now offers three launch modes to suit different workflows:

1. **Dashboard (tmux-based)** - Traditional terminal layout
2. **WebUI (Browser-based)** - Web interface with embedded terminals
3. **Debug Mode** - Single LLM CLI with KB/RAG integration

---

## Web Terminal (Browser-Based)

### Features

- **xterm.js Integration**: Full terminal emulation in your browser
- **PTY Backend**: Real pseudo-terminal sessions for each agent
- **WebSocket Streaming**: Real-time I/O between browser and server
- **Tabbed Interface**: Multiple terminals with easy switching
- **No tmux Required**: Entirely browser-based workflow

### Getting Started

1. **Launch WebUI**:
   ```bash
   ./launch.sh
   # Select option 2: WebUI (Browser-based)
   ```

2. **Open Browser**:
   Navigate to http://localhost:8080

3. **Open Web Terminal**:
   Click the "Web Terminal" tab in the navigation

4. **Spawn Terminals**:
   Click any of the spawn buttons:
   - **+ Conductor** - Project management agent
   - **+ Qwen** - Qwen-code LLM CLI
   - **+ Gemini** - Gemini-cli LLM CLI
   - **+ Claude** - Claude-code LLM CLI
   - **+ Debug Shell** - Bash shell with project context

### Terminal Controls

| Action | Control |
|--------|---------|
| Switch terminals | Click tab |
| Close terminal | Click × on tab |
| Close all | Click "Close All" |
| Full screen | Double-click terminal |
| Copy text | Select and Ctrl+C |
| Paste | Ctrl+V or Shift+Insert |

### How It Works

```
┌─────────────────────────────────────────┐
│  Browser (xterm.js)                     │
│  ┌─────────┬─────────┬─────────┐       │
│  │Conductor│  Qwen   │ Gemini  │       │
│  └─────────┴─────────┴─────────┘       │
└─────────────────────────────────────────┘
           ↑↓ WebSocket (Socket.IO)
┌─────────────────────────────────────────┐
│  WebUI (Flask + PTY Manager)            │
│  - Spawns PTY sessions                  │
│  - Streams I/O via WebSocket            │
│  - Manages process lifecycle            │
└─────────────────────────────────────────┘
           ↑↓ subprocess
┌─────────────────────────────────────────┐
│  Agent Processes (qwen, gemini, etc.)   │
└─────────────────────────────────────────┘
```

### API Reference

**Spawn Terminal**:
```bash
curl -X POST http://localhost:8080/api/terminal/spawn \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "type": "qwen"}'
```

**Close Terminal**:
```bash
curl -X POST http://localhost:8080/api/terminal/close \
  -H "Content-Type: application/json" \
  -d '{"id": 1}'
```

**WebSocket Events**:
- `terminal_input` - Send keystrokes to terminal
- `terminal_output` - Receive terminal output
- `terminal_resize` - Resize terminal (rows/cols)
- `terminal_closed` - Terminal session ended

---

## Debug Mode

### Purpose

Debug Mode provides a focused troubleshooting session with:
- Dedicated LLM CLI (your choice)
- Full project context loaded
- KB/RAG integration for knowledge search
- No distractions from other agents

### Launch Debug Mode

```bash
./launch.sh
# Select option 3: Debug Mode
```

Then choose your agent:
1. **Qwen** (qwen-code)
2. **Gemini** (gemini-cli)
3. **Claude** (claude-code)
4. **DeepSeek** (deepseek-cli)

### What Gets Loaded

| Resource | Location | Purpose |
|----------|----------|---------|
| Product Definition | `conductor/product.md` | Project goals and scope |
| Tech Stack | `conductor/tech-stack.md` | Architecture decisions |
| Knowledge Base | `conductor/knowledge_base_map.md` | Architectural knowledge |
| RAG Index | `.ai-colab/rag/` | Indexed source files |

### Available Commands

| Command | Description |
|---------|-------------|
| `!kb <query>` | Search knowledge base |
| `!rag <query>` | Search indexed documents |
| `!status` | Get project status |
| `!build` | Run build and tests |
| `!files <pattern>` | Search project files |

### Example Debug Session

```
$ ./launch.sh
# Select: 3 (Debug Mode)
# Select: 1 (Qwen)

Starting debug mode with qwen...
✓ RAG system available
✓ Knowledge base loaded (450 lines)

Project Context:
  • Root: /home/rchennau/ai_colab
  • KB: /conductor/knowledge_base_map.md
  • RAG: /.ai-colab/rag/

> "The web console isn't receiving conductor responses. Help me debug."

[Qwen analyzes the issue...]

I'll help debug the web console issue. Let me search the knowledge base first.

!kb web console conductor

[Searching knowledge base...]

Found relevant entries:
- Web Console uses hcom send to communicate
- Conductor listens for @conductor messages
- Check conductor agent status with: hcom list

Let me check if the conductor agent is running:

!status

[Getting project status...]

The conductor agent appears stale. Let's verify:

hcom list

[Lists active agents...]

I see the issue - the conductor agent name has a dynamic suffix. 
The web console needs to find the correct name. Let me check the code...

!files "*console*"

[Searching files...]
```

### When to Use Debug Mode

| Scenario | Recommended |
|----------|-------------|
| Troubleshooting agent issues | ✅ Yes |
| Debugging integration problems | ✅ Yes |
| Understanding codebase | ✅ Yes |
| Running complex multi-agent tasks | ❌ Use Dashboard |
| Production workflow | ❌ Use Dashboard or WebUI |

---

## Comparison: Launch Modes

| Feature | Dashboard | WebUI | Debug Mode |
|---------|-----------|-------|------------|
| **Interface** | tmux panes | Browser tabs | Single CLI |
| **Multi-agent** | ✅ Yes | ✅ Yes | ❌ Single |
| **KB/RAG** | Via commands | Via UI | ✅ Integrated |
| **Conductor** | ✅ Full | ✅ Via terminal | ✅ Context loaded |
| **Browser Access** | ❌ No | ✅ Yes | ❌ No |
| **Best For** | Power users | Remote work | Troubleshooting |

---

## Troubleshooting

### Web Terminal Issues

**Problem**: Terminal doesn't spawn
```
Error: PTY manager not initialized
```
**Solution**: Restart WebUI server
```bash
pkill -f "python.*webui/app.py"
./launch.sh  # Select WebUI option
```

**Problem**: Terminal output is garbled
**Solution**: Resize terminal window or click "Close All" and respawn

**Problem**: WebSocket connection fails
**Solution**: Check browser console, ensure Socket.IO is loading
```
https://cdn.socket.io/4.5.4/socket.io.min.js
```

### Debug Mode Issues

**Problem**: Agent command not found
```
Error: qwen-code is not installed
```
**Solution**: Install LLM CLI tools
```bash
./install.sh
# Select your LLMs during setup
```

**Problem**: KB/RAG not available
```
○ RAG not installed (optional)
```
**Solution**: Install RAG dependencies
```bash
pip install sentence-transformers
```

---

## Advanced Configuration

### Custom Terminal Types

Add custom terminal types in `webui/app.py`:

```python
commands = {
    'custom': ['your-command', '--with-args'],
    # ...
}
```

### Debug Mode Context

Customize loaded context in `scripts/debug-mode.sh`:

```bash
# Add your custom files to context
context+="=== CUSTOM FILE ===\n"
context+="$(cat /path/to/file.md)\n\n"
```

### PTY Settings

Adjust PTY defaults in `webui/app.py`:

```python
# Default terminal size
term = Terminal(rows=24, cols=80)

# Adjust buffer size
output = os.read(fd, 4096)  # Increase for faster output
```
