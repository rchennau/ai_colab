# ai-colab: Multi-Agent Collaboration Framework

A unified, **project-agnostic** environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering tasks.

## 🌟 Vision
To provide a seamless development experience where human oversight and AI autonomy work in harmony. ai-colab handles the "plumbing" of multi-agent systems—messaging, state synchronization, task tracking, and lifecycle management—allowing you to focus on the engineering.

## 🚀 Quick Start

### Installation Pathways

ai-colab supports multiple installation pathways to suit your workflow:

#### **Option 1: Interactive CLI Wizard (Recommended)**

Guided terminal-based setup for your native environment:

```bash
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab
./install.sh --wizard
```

#### **Option 2: Docker & Web UI**

Browser-based setup and containerized management:

```bash
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab
docker-compose up -d
```

Then open: http://localhost:8080

#### **Option 3: Quick/Auto Install**

Automated installation with sensible defaults (for CI/CD):

```bash
./install.sh --auto
```

### Launch the Dashboard

After installation:

```bash
./launch.sh
```

Choose your agents and active modules. Start collaborating in the **Unified Command Center**—a high-density tmux dashboard featuring real-time hcom monitoring, automated conductor logs, and a dedicated user console.

📖 **Full Documentation:** See [`docs/INSTALLATION.md`](docs/INSTALLATION.md) for detailed installation guide.

## 🏗️ Core Architecture

ai-colab follows a **'Hub and Spoke'** model to separate orchestration from compute:

### **Orchestration Hub (Self-Hosted)**
The **Hub** is the central controller. It is designed to be **self-hosted** (locally or via Docker).
> **⚠️ Important:** The `ai-colab-core` Docker image contains **ONLY** the orchestration components (hcom relay, Conductor, Blackboard, Web UI) and remote connectors (client CLIs). It does **NOT** run LLM models or agent logic internally; these run externally as 'Spokes'.

- **hcom Relay**: The messaging backbone for the entire fleet.
- **Conductor**: The project orchestrator and task manager.
- **Shared Blackboard**: Real-time state synchronization (hcom-kv).
- **Remote Connectors**: Client CLIs used to communicate with remote models.

### **Remote Spokes (Agents & Compute)**
High-power agents and models run **externally** to the Hub:
- **nemoclaud**: Hosted on NVIDIA NIM API or specialized cloud pods (RunPod).
- **Remote LLMs**: Accessed via Gemini, Claude, and Qwen remote APIs.
- **Fleet Workers**: Specialized agents running on distributed hardware.

### **Intelligent Orchestration**
*   **Automated Git Lifecycle:** Isolated branches, auto-commits, and pseudo-PRs.
*   **Semantic Knowledge Base:** LLM-powered architectural search (`!kb`).
*   **Unified Dashboard (v3.0):** High-density real-time TUI and optional Web UI.

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
| `./install.sh` | Master installer with `--wizard`, `--reconfigure`, and `--guide` |
| `./launch.sh` | Unified launcher with interactive module and agent selection |
| `scripts/config-manager.sh` | Central configuration management and schema validation |
| `scripts/install-wizard.sh` | Interactive terminal-based configuration wizard |
| `scripts/agent-wrapper.sh` | Unified registration, heartbeats, and role injection |
| `scripts/conductor-workflow.sh`| The orchestration heart (Git, KB, Tasking) |
| `scripts/hcom-test-runner.sh` | Unified test execution and blackboard reporting |
| `scripts/hcom-kb-index.sh` | Generates the semantic project map for `!kb` |
| `scripts/conductor-dashboard.sh`| Renders the high-density terminal dashboard |
| `webui/app.py` | Flask-based Web UI and API backend |
| `tests/test_config_manager.sh` | Automated validation of the configuration system |
| `tests/test_install_wizard.sh` | Integration tests for the installer and CLI experience |

---

## 🌐 Web UI

ai-colab includes a comprehensive Web UI for browser-based management:

- **Setup Wizard**: Interactive configuration via browser
- **Dashboard**: Real-time system status and agent monitoring
- **Configuration Editor**: Visual config management with validation
- **Logs Viewer**: Real-time log streaming and filtering
- **Agent Management**: Start, stop, and monitor agents

**Access**: http://localhost:8080 (when running via Docker)

📖 **Guide:** See [`docs/WEBUI_GUIDE.md`](docs/WEBUI_GUIDE.md)

## 📋 Best Practices

### **Agent Naming**
Always use **lowercase letters, numbers, and underscores** (e.g., `gemini_dev`). Hyphens and uppercase characters are restricted by the `hcom` protocol.

### **Git-Awareness**
The Conductor creates branches named `track/<slug>`. Agents are instructed to work in these branches. Always use `!approve <slug>` to finalize a track; this ensures that only verified (passing tests) code is merged into your main branch.

### **Persistent Presence**
Agents use a 20s background heartbeat to stay "ready" in the TUI without flooding the event stream. They will automatically restart if the LLM CLI process crashes or times out.

## 📝 License
Part of the hcom utilities ecosystem.

