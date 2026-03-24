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

### **The Conductor & QA Automation (Milestone 3 & 4)**
The **Conductor** is the project's "orchestrator." It maintains the Source of Truth in `conductor/tracks.md`, ensuring all agents are aligned on tasks and project state.
*   **Automated Testing:** Periodically runs the `hcom-test-runner.sh` to ensure build health and syncs status to the Blackboard.
*   **Visual Debugging:** Captures periodic screenshots of the Atari emulator for visual state analysis.
*   **Interactive Commands:** Any agent can now send commands to the Conductor via `hcom`:
    *   `!status`: Summarizes project progress, active track, and test health.
    *   `!test`: Triggers an immediate full test suite run.
    *   `!screenshot`: Captures a new Atari screen state for the team.
    *   `!build`: Triggers the local project's build system (`make`).
    *   `!git-sync`: Synchronizes with the remote repository.
    *   `!switch <path>`: Swaps the Conductor's focus to a different project directory.

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
| `scripts/conductor-workflow.sh` | Automated background manager with command processing and QA monitoring. |
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
- **Persistent Status (v2.2.3):** Agents now maintain a background 10s heartbeat using `hcom start`, which ensures they stay "ready" in the TUI without "stealing" messages (as a full `hcom listen` would). This solves the `exit:timeout` cycling issue.
- **Status Persistence:** Agents maintain their `listening` status as long as their primary interactive CLI process is running.
- **Location:** `scripts/utils.sh` (`start_heartbeat()` function) and `scripts/agent-wrapper.sh`.

### **Automatic Agent Restart (v2.2)**
As of agent-wrapper.sh v2.2, agents automatically restart if they exit unexpectedly. This ensures persistent presence in the hcom TUI even when LLM CLI tools have internal idle timeouts.

### **Dashboard Reliability (v2.2.2)**
To prevent agent loading failures and syntax errors in complex tmux environments (especially on macOS), the following improvements were made:
- **Syntax Correction:** Resolved shell syntax errors in the `main` loop of `dashboard-launch.sh` that caused intermittent launch failures.
- **Initialization Stability:** Increased shell initialization delays (1.0s) and added a secondary title refresh (2.0s) to ensure that `tmux send-keys` and pane titles are correctly applied without being overwritten by the shell's own startup sequence.
- **Path Resolution:** The `hcom` binary path is now explicitly resolved during launch (supporting `~/.local/bin` and `/usr/local/bin`).
- **Window Addressing:** Uses named windows (`dashboard`, `conductor`, `bridge`) instead of numeric indices for robust pane management.
- **Project Context:** New panes are automatically created in the current project root directory to ensure local configuration and scripts are immediately available.

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
