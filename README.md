# ai-colab: Multi-Agent Collaboration Framework

A unified, **project-agnostic** environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering tasks.

## 🌟 Vision
To provide a seamless development experience where human oversight and AI autonomy work in harmony. ai-colab handles the "plumbing" of multi-agent systems—messaging, state synchronization, task tracking, and lifecycle management—allowing you to focus on the engineering.

## 🚀 Quick Start

1.  **Clone and Install:**
    ```bash
    git clone https://github.com/rchennau/ai_colab.git
    cd ai_colab
    ./install.sh
    ```
    This script handles all dependencies (hcom, LLM CLIs, tmux, sqlite3). You will be prompted to install optional **Addon Modules** (like Atari-LX).

2.  **Launch the Dashboard:**
    ```bash
    ./launch.sh
    ```
    Choose your agents and active modules. Start collaborating in the **v3.0 Unified Command Center**—a high-density tmux dashboard featuring real-time hcom monitoring, automated conductor logs, and a dedicated user console.

## 🏗️ Core Architecture

### **Intelligent Orchestration**
The **Conductor** is the project's "orchestrator," managing the project plan (`conductor/tracks.md`).
*   **Automated Git Lifecycle (New!):** Automatically creates branches for new tasks, commits progress upon successful testing, and manages "Pseudo-PRs" for your approval.
*   **Semantic Knowledge Base (New!):** An LLM-powered RAG system. Use `!kb <query>` to search the entire codebase for architectural guidance, not just documentation.
*   **Unified Dashboard (v3.0):** A high-density project summary showing Milestone progress, active tasks, and recent hcom events in a single pane.

### **hcom (Hook-Comms)**
The backbone of ai-colab. All agents communicate via [hcom](https://github.com/aannoo/hcom):
*   **Inter-agent messaging:** Agents can "talk" to each other, hand off tasks, and request reviews.
*   **Shared Blackboard:** A lightweight KV store (`hcom-kv`) for sharing state (e.g., current task, performance metrics).
*   **Standardized Commands:** Send commands to the Conductor from any agent or the console:
    *   `!status`: Project health, progress, and active tracks.
    *   `!test`: Triggers the automated test suite.
    *   `!approve <slug>`: Merges a completed task branch into the project root.
    *   `!kb <query>`: Semantic search for architectural guidance.
    *   `!build`: Triggers the project's local build system.

## 🧩 Addon Modules

ai-colab is designed to be project-agnostic. Specialized functionality is provided via modules:

### **Atari-LX Development**
Deep integration for 6502 assembly and Atari 8-bit hardware.
- ✅ Visual Memory Map Generator (`!memory-map`)
- ✅ Historical Performance Trending (`!perf-trend`)
- ✅ Automated Screen Capture & Sync (`!screenshot`)
- ✅ Technical Debate Mode for optimizations.

📖 **See:** [`modules/atari-lx/README.md`](modules/atari-lx/README.md)

---

## 💻 Terminal Setup

ai-colab includes **automatic terminal detection and optimization** for the best multi-agent experience.

### **macOS + iTerm2 (Recommended)**
iTerm2 provides superior pane management and shell integration.
📖 **Guide:** [`docs/ITERM2_SETUP.md`](docs/ITERM2_SETUP.md)

### **WSL2 Ubuntu + Windows Terminal**
Full support for WSL2 with Windows Terminal optimizations.
📖 **Guide:** [`docs/WSL_SETUP.md`](docs/WSL_SETUP.md)

---

## 🛠️ Key Scripts

| Script | Purpose |
|--------|---------|
| `./install.sh` | Project-agnostic core installer + module selection. |
| `./launch.sh` | Unified launcher with module enablement. |
| `scripts/agent-wrapper.sh` | Unified registration, heartbeats, and role injection. |
| `scripts/conductor-workflow.sh`| The orchestration heart (Git, KB, Tasking). |
| `scripts/hcom-test-runner.sh` | Unified test execution and blackboard reporting. |
| `scripts/hcom-kb-index.sh` | Generates the semantic project map for `!kb`. |
| `scripts/conductor-dashboard.sh`| Renders the v3.0 high-density TUI. |

---

## 📋 Best Practices

### **Agent Naming**
Always use **lowercase letters, numbers, and underscores** (e.g., `gemini_dev`). Hyphens and uppercase characters are restricted by the `hcom` protocol.

### **Git-Awareness**
The Conductor creates branches named `track/<slug>`. Agents are instructed to work in these branches. Always use `!approve <slug>` to finalize a track; this ensures that only verified (passing tests) code is merged into your main branch.

### **Persistent Presence**
Agents use a 20s background heartbeat to stay "ready" in the TUI without flooding the event stream. They will automatically restart if the LLM CLI process crashes or times out.

## 📝 License
Part of the hcom utilities ecosystem.

