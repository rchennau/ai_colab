# ai-colab: Multi-Agent Collaboration Framework

A unified environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering projects.

## 🚀 Quick Start

1.  **Clone and Install:**
    ```bash
    git clone https://github.com/rchennau/ai_colab.git
    cd ai_colab
    ./install.sh
    ```
    This script handles all dependencies (hcom, LLM CLIs, tmux, sqlite3, and project-specific tools). 
    
    *Note: Zsh users should run `source ~/.zshrc` after the script finishes to enable aliases and path updates.*

2.  **Launch the Dashboard:**
    ```bash
    ./launch.sh
    ```
    Choose your agents and start collaborating in a unified tmux-based dashboard with real-time status tracking.

## 🏗️ Core Architecture

### **The Conductor**
The **Conductor** is the project's "orchestrator." It maintains the Source of Truth in `conductor/tracks.md`, ensuring all agents are aligned on tasks and project state.

### **hcom (Hook-Comms)**
All agents communicate via [hcom](https://github.com/aannoo/hcom), a message-passing protocol that enables:
*   **Inter-agent messaging:** Agents can "talk" to each other, hand off tasks, and request reviews.
*   **Shared Blackboard:** A lightweight KV store (`hcom-kv`) for sharing state (e.g., current task, progress percentages).
*   **Unified TUI:** Monitor all agents and their messages in a single dashboard.

## 🛠️ Key Scripts

| Script | Purpose |
|--------|---------|
| `./install.sh` | Master installer for dependencies and LLM CLIs. |
| `./launch.sh` | Unified launcher for the Dashboard and Conductor. |
| `scripts/agent-wrapper.sh` | The unified core for registration, heartbeats, and roles. |
| `scripts/*-hcom.sh` | Lightweight wrappers (Gemini, Qwen, vLLM via **ELC**, etc.) with standardized hcom identity and status tracking. |
| `scripts/conductor-workflow.sh` | Automated background manager for track progress and worker spawning. |
| `scripts/atari-debate.sh` | Automates technical debates between active agents (including vLLM Atari expert). |

## 🕹️ Project Context: Atari-LX
This repository is pre-configured for **Atari-LX Engineering**, featuring deep integration with the Atari 8-bit hardware environment, shared constants, and automated technical debates for optimized 6502 assembly development.

## 📝 License
Part of the hcom utilities ecosystem.

## 📋 Best Practices & Troubleshooting

### **Agent Naming (hcom 0.7.5+)**
Always use **lowercase letters, numbers, and underscores** for agent names. Hyphens and uppercase characters are restricted and may cause identity resolution failures (e.g., `gemini_dev` instead of `gemini-dev`). 

### **Agent Pulse (Heartbeats)**
Agent wrappers (`*-hcom.sh`) include a background pulse loop that calls `hcom listen` every 10 seconds. This ensures that even idle or interactive agents (like Qwen or vLLM) maintain a stable `listening` status in the TUI and are not marked as `exit:timeout`.

**Technical Details:**
- Heartbeat timeout: 10 seconds (prevents timeout status)
- Fallback sleep: 5 seconds (ensures rapid reconnection)
- Location: `scripts/agent-wrapper.sh` and `scripts/utils.sh`

### **Configuration Validation**
If `hcom` warns about an invalid `config.toml`, check for literal `\n` characters or missing `=` signs. Run `hcom status` to verify your configuration is valid.

### **vLLM Integration (via easy-llm-cli)**
For high-performance local inference, the `vllm_dev` agent now uses **easy-llm-cli (ELC)**. This provides a Gemini-like terminal interface while connecting to your local vLLM OpenAI-compatible server.

### **Consolidated Agent Architecture**
All agents now use a unified `scripts/agent-wrapper.sh` to handle registration, heartbeats, and model selection. This ensures consistent behavior across all providers (Gemini, Qwen, Claude, DeepSeek, NeMo, and ELC/vLLM) and simplifies the codebase by moving common logic into `utils.sh`.

### **Role-Based Multi-Agent Intelligence**
Agents now have specialized roles and system prompts to optimize their contributions to the Atari-LX project:
- **Gemini**: Architect & Orchestrator (Project Lead)
- **Qwen**: Assembly & Hardware Expert (Timing-critical code)
- **DeepSeek**: Logic & Optimization Specialist (Algorithms & C optimization)

### **Atari-Dev-Agent MCP**
All agents are now pre-configured with the **atari-dev-agent** MCP server. This provides specialized tools for:
- 6502 code validation and cycle counting
- Knowledge base searching
- Interrupt safety checking
- Emulator screen analysis

### **How to use MCP Tools**
All agents can now call specialized Atari tools. You can manually trigger them in chat or let the agents use them autonomously:
- `validate_6502_code(code)`: Checks for common errors (missing CLC/SEC, etc).
- `count_cycles(code)`: Exact cycle timing for scanline optimization.
- `search_kb(query)`: Search the Atari-LX knowledge base.
- `analyze_atari_screen(image_path)`: Visual debugging via OCR/Vision.
