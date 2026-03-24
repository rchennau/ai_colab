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
    Choose your agents and start collaborating in the **v2.3 Unified Command Center**—a high-density tmux dashboard featuring real-time hcom monitoring, automated conductor logs, and a dedicated user console.

## 💻 Terminal Setup (NEW!)

ai-colab now includes **automatic terminal detection and optimization** for the best multi-agent experience.

### **macOS + iTerm2 (Recommended)**

iTerm2 provides the best experience for ai-colab with superior pane management, scrollback, and shell integration.

```bash
# Install iTerm2
brew install --cask iterm2

# Run installer (auto-detects iTerm2)
./install.sh

# Accept prompt to install iTerm2-optimized tmux config
```

**Features:**
- ✅ True color support for beautiful tmux themes
- ✅ Unicode & ligature support for code
- ✅ Enhanced scrollback (100,000 lines)
- ✅ Shell integration with status indicators
- ✅ Clipboard integration (tmux → macOS)

📖 **Complete Setup Guide:** [`docs/ITERM2_SETUP.md`](docs/ITERM2_SETUP.md)

### **WSL2 Ubuntu + Windows Terminal**

Full support for WSL2 with Windows Terminal optimizations.

```bash
# In WSL2 Ubuntu
./install.sh

# Auto-detects WSL and configures Windows Terminal
# Accept prompt to install WSL-optimized tmux config
```

**Features:**
- ✅ Windows clipboard integration
- ✅ True color and Unicode support
- ✅ Windows Terminal interop (explorer.exe, clip.exe)
- ✅ Optimized for WSL2 filesystem performance

📖 **Complete Setup Guide:** [`docs/WSL_SETUP.md`](docs/WSL_SETUP.md)

### **Automatic Detection**

The installer automatically detects your terminal and applies optimizations:

```bash
# Check what terminal you're using
./scripts/terminal-detect.sh

# Supported terminals:
# - iTerm2 (macOS)
# - Windows Terminal (WSL)
# - VS Code Terminal
# - macOS Terminal.app
# - Linux terminals (gnome-terminal, kitty, etc.)
```

---

### **Intelligent Orchestration (Milestone 3, 4 & 5)**
The **Conductor** is the project's "orchestrator." In v2.3, it is integrated directly into the Dashboard's right column for seamless monitoring.
*   **Unified Command Center (v2.3)**:
    *   **Left Column**: `hcom` TUI for message monitoring.
    *   **Top Right**: **Conductor Log Pane** for real-time task tracking.
    *   **Bottom Right**: LLM Agent stack (Gemini, Qwen, etc.).
    *   **Bottom Console**: Dedicated **User Command Console** pre-registered with `hcom` and custom aliases (`s` for status, `t` for test, `b` for build).
*   **Track Dependency Tracking**: Automatically handles track dependencies, ensuring workers are only spawned for "ready" tasks.

*   **Automated QA & Review:** Periodically runs the `hcom-test-runner.sh` and `hcom-code-review.sh` to ensure build health and style compliance.
*   **Visual Debugging:** Captures periodic screenshots of the Atari emulator for visual state analysis.
*   **Interactive Commands:** Any agent can now send commands to the Conductor via `hcom`:
    *   `!status`: Summarizes project progress, active track, and test health.
    *   `!test`: Triggers an immediate full test suite run.
    *   `!screenshot`: Captures a new Atari screen state for the team.
    *   `!build`: Triggers the local project's build system (`make`).
    *   `!git-sync`: Synchronizes with the remote repository.
    *   `!switch <path>`: Swaps the Conductor's focus to a different project directory.
    *   `!kb <query>`: Searches the project's architectural knowledge base (conductor/).
    *   `!profile <file>`: Analyzes 6502 assembly for cycle counts and performance bottlenecks.

### **hcom (Hook-Comms)**
All agents communicate via [hcom](https://github.com/aannoo/hcom), a message-passing protocol that enables:
*   **Inter-agent messaging:** Agents can "talk" to each other, hand off tasks, and request reviews.
*   **Shared Blackboard:** A lightweight KV store (`hcom-kv`) for sharing state (e.g., current task, progress percentages).
*   **Unified TUI:** Monitor all agents and their messages in a single dashboard.
*   **Blackboard Automation:** The Conductor script (`conductor-workflow.sh`) automatically syncs `tracks.md` when agents complete tasks on the blackboard.

## 🛠️ Key Scripts

| Script | Purpose |
|--------|---------|
| `./install.sh` | Master installer for dependencies and LLM CLIs. |
| `./launch.sh` | Unified launcher for the Dashboard and Conductor. |
| `scripts/agent-wrapper.sh` | The unified core for registration, heartbeats, and roles. |
| `scripts/hcom-test-runner.sh` | Unified test execution and blackboard reporting (v2.2.3). |
| `scripts/hcom-code-review.sh` | Automated code review against style guides using Gemini. |
| `scripts/hcom-profiler.sh` | Performance analysis using the atari-dev-agent MCP. |
| `scripts/conductor-workflow.sh` | Automated manager with command processing, dependency tracking, and QA. |
| `scripts/atari-debate.sh` | Automates technical debates between active agents. |
| `scripts/hcom-kv.sh` | Standardization script for reading/writing the Shared Blackboard. |
| `scripts/hcom-chat-bridge.sh` | Forwards project events and visual debug updates to Google Chat. |

## 🕹️ Project Context: Atari-LX
This repository is pre-configured for **Atari-LX Engineering**, featuring deep integration with the Atari 8-bit hardware environment, shared constants, and automated technical debates for optimized 6502 assembly development.

## 📝 License
Part of the hcom utilities ecosystem.

## 📋 Best Practices & Troubleshooting

### **Agent Naming (hcom 0.7.5+)**
Always use **lowercase letters, numbers, and underscores** for agent names. Hyphens and uppercase characters are restricted and may cause identity resolution failures (e.g., `gemini_dev` instead of `gemini-dev`). 

### **Agent Pulse (Heartbeats)**
Agent wrappers register their identity with `hcom start` upon initialization. This ensures that agents show up correctly in the TUI (`hcom list`). 

**Technical Details:**
- **Lightweight Pulse (v2.2.4):** Agents now maintain a background 20s heartbeat using `hcom status --name`. This updates their "last seen" timestamp in the TUI without emitting disruptive "created" events or displacing active interactive sessions. This resolves the `exit:timeout` flapping and TUI event noise.
- **Status Persistence:** Agents maintain their `listening` status as long as their primary interactive CLI process is running.
- **Location:** `scripts/utils.sh` (`start_heartbeat()` function) and `scripts/agent-wrapper.sh`.

### **Automatic Agent Restart (v2.2)**
As of agent-wrapper.sh v2.2, agents automatically restart if they exit unexpectedly. This ensures persistent presence in the hcom TUI even when LLM CLI tools have internal idle timeouts.

### **Dashboard Reliability (v2.3.1)**
To prevent agent loading failures and "no space for new pane" errors in high-density tmux environments, the following improvements were made:
- **Dynamic Pane IDs:** The dashboard now uses internal tmux pane IDs (`#{pane_id}`) instead of numeric indices (`.0`, `.1`). This ensures that agents and consoles are launched into the correct panes even as tmux re-indexes them during the split process.
- **Space Balancing:** Added automated space balancing (`select-layout tiled`) and improved splitting logic to ensure that new panes have sufficient room to initialize. This resolves the common `no space for new pane` error on smaller terminal windows.
- **Improved Focus Logic:** Uses pane IDs to reliably focus the user console upon startup, regardless of the number of active agents.
- **Syntax Correction:** Resolved shell syntax errors in the `main` loop of `dashboard-launch.sh` that caused intermittent launch failures.

### **Configuration Validation**
If `hcom` warns about an invalid `config.toml`, check for literal `\n` characters or missing `=` signs. Run `hcom status` to verify your configuration is valid.

### **Dashboard Pane Titles**
The tmux dashboard uses a dual-labeling system to ensure agent names remain visible even when their CLI tools update the pane title with status messages:
- **Persistent Label (`@agent_name`):** Each pane has a persistent, capitalized name (e.g., `[Gemini]`, `[Qwen]`) stored in a custom tmux option.
- **Dynamic Status (`pane_title`):** The dynamic title from the agent's CLI (e.g., `✦ Working…`) is displayed alongside the persistent label.
- **Improved UI:** Borders use a dark, subtle color scheme with an `[Atari-LX]` cap on the right for a clean, professional look.

To manually re-apply or check these labels:
- `tmux set-option -p @agent_name "NAME"` to set a persistent label.
- `tmux show-options -p` to verify the current pane's settings.

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

---

## 🖥️ Terminal Configuration Reference

### **tmux Configurations**

ai-colab includes terminal-optimized tmux configurations in `config/`:

| Configuration | File | Best For |
|--------------|------|----------|
| **iTerm2** | `tmux.iterm2.conf` | macOS + iTerm2 (recommended) |
| **Windows Terminal** | `tmux.windows-terminal.conf` | WSL2 + Windows Terminal |
| **Default** | `tmux.default.conf` | Fallback for all terminals |

**Install during setup:**
```bash
./install.sh  # Accept prompt to install terminal-specific config
```

**Or manually:**
```bash
# iTerm2
cp config/tmux.iterm2.conf ~/.tmux.conf

# WSL/Windows Terminal
cp config/tmux.windows-terminal.conf ~/.tmux.conf

# Reload tmux
tmux kill-server
tmux
```

### **Key Bindings (All Configs)**

| Action | Key Binding |
|--------|-------------|
| Prefix | `Ctrl-a` |
| Reload config | `Prefix + r` |
| Split vertical | `Prefix + \|` |
| Split horizontal | `Prefix + -` |
| Navigate panes | `Prefix + h/j/k/l` |
| Resize panes | `Prefix + H/J/K/L` |
| Copy to clipboard | `Prefix + y` |

### **Troubleshooting**

**Display issues:**
```bash
# Reset terminal type
export TERM=xterm-256color
export COLORTERM=truecolor

# Restart tmux
tmux kill-server
```

**Check terminal detection:**
```bash
./scripts/terminal-detect.sh
```

**Manual terminal setup:**
```bash
# Source terminal detection
source scripts/terminal-detect.sh
init_terminal
```
