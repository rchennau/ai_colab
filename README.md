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
- **nemoclaw**: Hosted on NVIDIA NIM API or specialized cloud pods (RunPod).
- **Remote LLMs**: Accessed via Gemini, Claude, and Qwen remote APIs.
- **Fleet Workers**: Specialized agents running on distributed hardware.

### **Intelligent Orchestration**
*   **Automated Git Lifecycle:** Isolated branches, auto-commits, and pseudo-PRs.
*   **Semantic Knowledge Base:** LLM-powered architectural search (`!kb`).
*   **Unified Dashboard (v3.0):** High-density real-time TUI and optional Web UI.
*   **80-Column ANSI UI:** Professional CLI graphics and status reporting across all core scripts.
*   **Project Migration Tool:** Automated detection and import of existing AI integrations.

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

## 🧩 Addon Modules (Examples)

ai-colab is designed to be project-agnostic. Specialized functionality is provided via modular addons:

### **Atari-8bit Development**
Example module for 6502 assembly and Atari 8-bit hardware.
- ✅ Visual Memory Map Generator (`!memory-map`)
- ✅ Historical Performance Trending (`!perf-trend`)
- ✅ Automated Screen Capture & Sync (`!screenshot`)
- ✅ Technical Debate Mode for optimizations.

📖 **See:** [`modules/atari-8bit/README.md`](modules/atari-8bit/README.md)

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
| `./install.sh` | Master installer with `--wizard`, `--reconfigure`, and `--auto` modes |
| `./install.sh --wizard` | Interactive CLI installation wizard (5-step guided setup) |
| `./install.sh --reconfigure` | Modify existing installation without reinstalling |
| `./launch.sh` | Unified launcher with interactive module and agent selection |
| `./scripts/migrate-project.sh` | Project Detection & Migration Tool (automated AI import) |
| `scripts/config-manager.sh` | Central configuration management and schema validation |
| `scripts/install-wizard.sh` | Interactive terminal-based configuration wizard |
| `scripts/utils.sh` | Shared utilities and 80-column ANSI UI helpers |
| `scripts/agent-wrapper.sh` | Unified registration, heartbeats, and role injection |
| `scripts/conductor-workflow.sh`| The orchestration heart (Git, KB, Tasking) |
| `scripts/hcom-test-runner.sh` | Unified test execution and blackboard reporting |
| `scripts/hcom-kb-index.sh` | Generates the semantic project map for `!kb` |
| `scripts/conductor-dashboard.sh`| Renders the high-density terminal dashboard (v2.4) |
| `scripts/dashboard-launch.sh` | Enhanced dashboard launcher (v2.4) with pre-flight checks and cross-version tmux compatibility |
| `webui/app.py` | Flask-based Web UI and API backend (v2.0) |
| `tests/test_webui.sh` | Automated Web UI test suite (8 tests) |
| `scripts/webui-test-watch.sh` | Local file watcher for automated testing |

---

## 🌐 Web UI

ai-colab includes a comprehensive Web UI for browser-based management:

### Features
- **Setup Wizard**: Interactive 5-step configuration via browser
- **Dashboard**: Real-time system status with health monitoring
- **Pre-flight Checks**: System readiness verification
- **Session Management**: View and recover tmux sessions
- **Agent Monitoring**: Real-time agent list from hcom
- **Configuration Editor**: Visual config management with validation
- **Logs Viewer**: Real-time log streaming and filtering

### Quick Start
```bash
# Docker deployment
docker-compose up -d

# Access at
http://localhost:8080
```

### New API Endpoints (v2.0)
- `GET /health` - Enhanced health with tmux/hcom/disk checks
- `GET /api/preflight` - Pre-flight checks (mirrors CLI)
- `GET /api/session/status` - tmux session monitoring
- `POST /api/session/recover` - Session recovery
- `GET /api/agents` - Real-time agent list
- `POST /api/dashboard/launch` - Launch dashboard from browser

**Access**: http://localhost:8080 (when running via Docker)

📖 **Guide:** See [`docs/WEBUI_GUIDE.md`](docs/WEBUI_GUIDE.md)  
📖 **Testing:** See [`docs/AUTOMATED_WEBUI_TESTING.md`](docs/AUTOMATED_WEBUI_TESTING.md)

---

## 🧪 Automated Testing

### Web UI Test Suite
- **8 automated tests** covering all API endpoints
- **GitHub Actions** CI/CD integration
- **Local file watcher** for real-time feedback during development
- **Test status badges** for visibility

### Run Tests
```bash
# Manual test run
./tests/test_webui.sh

# Start file watcher (auto-runs on changes)
./scripts/webui-test-watch.sh
```

### Test Coverage
- ✅ Health endpoint with system checks
- ✅ Pre-flight checks API
- ✅ Session status monitoring
- ✅ Agent list from hcom
- ✅ Configuration management
- ✅ System status endpoint
- ✅ Dashboard launch endpoint
- ✅ Frontend HTML verification

**Status:** 8/8 tests passing ✅

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

