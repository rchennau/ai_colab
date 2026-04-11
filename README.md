# ai-colab: Multi-Agent Collaboration Framework

A unified, **project-agnostic** environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering tasks.

**Latest Release:** Phase 17 Complete ✅ — Console UX Revolution with adaptive layouts, focus mode, enhanced console, real-time status bar, and session persistence.

## 🌟 Vision
To provide a seamless development experience where human oversight and AI autonomy work in harmony. ai-colab handles the "plumbing" of multi-agent systems—messaging, state synchronization, task tracking, and lifecycle management—allowing you to focus on the engineering.

## 🚀 Quick Start

### Installation Pathways

ai-colab supports multiple installation pathways to suit your workflow:

#### **Option 1: Global CLI (Recommended)**

Install ai-colab globally to manage any project on your system:

```bash
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab
./install.sh --global
```

This creates a global `ai-colab` command. You can now run `ai-colab` in any git repository to start managing it.

#### **Option 2: Native/Local Install**

Guided terminal-based setup for the current directory:

```bash
./install.sh --wizard
```

#### **Option 3: Docker & Web UI**

Browser-based setup and containerized management:

```bash
docker-compose up -d
```

Then open: http://localhost:8080

### Portable Python & Isolation

ai-colab ensures true portability and zero interference with your system:
- **Zero OS Dependency**: Uses `uv` to download standalone Python 3.11 distributions.
- **Intelligent Detection**: Automatically detects **uv**, **conda**, **pixi**, or **venv**.
- **Isolated Runtimes**: Every project runs in its own dedicated, high-performance environment.

📖 **Full Details:** See [`docs/INSTALLATION.md`](docs/INSTALLATION.md) and [`PYTHON_ENV_SETUP.md`](PYTHON_ENV_SETUP.md)

### Launch the Command Center

After installation, simply run:

```bash
ai-colab
```

**Choose your launch mode:**

1. **Dashboard (v3.0)** - Adaptive tmux layout with real-time status bar and focus mode.
2. **WebUI (v3.0)** - Modular blueprint-based interface with project switcher and persistent logs.
3. **Debug Mode** - Specialized troubleshooting environment with deep KB/RAG context.

**Dashboard Features (Phase 17 Complete ✅):**
- **Dynamic Layouts:** Auto-adapts to agent count (1-2: side-by-side, 3-4: grid, 5-7: tabbed, 8+: compact)
- **Focus Mode:** `Ctrl+b f` to zoom single agent pane, `Ctrl+b 1-9` to switch between agents
- **Real-Time Status Bar:** Color-coded fleet status in tmux status line (✓ ready, ⏳ busy, ✗ crashed)
- **Enhanced Console:** Python readline-based interface with command history, tab completion, and help
- **Session Persistence:** Auto-saves layout on creation, restore with `bash scripts/restore-layout.sh`
- **Named Layout Presets:** Save/restore layouts as `default`, `coding`, `review`, or custom names

**Multi-Project Support:**
Running `ai-colab` will scan for local git repositories and allow you to register and switch between them seamlessly.

### Testing & Quality Gates

Ensure code integrity with the built-in quality assurance framework:

```bash
# Run all quality gates (Linting, Security, Syntax)
./scripts/quality-gates.sh

# Run comprehensive test suite
./scripts/test-launch-options.sh
```

**Quality Gates:**
- ✅ **Python Syntax**: Recursive validation across all project files.
- ✅ **Linting**: Strict `flake8` enforcement for clean code.
- ✅ **Security**: `bandit` scanning for potential vulnerabilities.
- ✅ **Functional**: Conductor-integrated test runs before any merge.

📖 **Full Documentation:** See [`docs/INSTALLATION.md`](docs/INSTALLATION.md) for detailed installation guide.
📖 **Web Terminal Guide:** See [`docs/WEB_TERMINAL_GUIDE.md`](docs/WEB_TERMINAL_GUIDE.md) for browser-based workflow.

## 🏗️ Core Architecture

ai-colab follows a **'Hub and Spoke'** model to separate orchestration from compute:

### **Orchestration Hub (Self-Hosted)**
The **Hub** is the central controller. It is designed to be **self-hosted** (locally or via Docker).
- **hcom Relay**: The messaging backbone for the entire fleet.
- **Conductor**: The project orchestrator and task manager.
- **Shared Blackboard**: Real-time state synchronization (hcom-kv) with **schema validation**.
- **Remote Connectors**: Client CLIs used to communicate with remote models.

### **Remote Spokes (Agents & Compute)**
High-power agents and models run **externally** to the Hub:
- **nemoclaw**: Hosted on NVIDIA NIM API or specialized cloud pods (RunPod).
- **Remote LLMs**: Accessed via Gemini, Claude, and Qwen remote APIs.
- **Fleet Workers**: Specialized agents running on distributed hardware.

### **Intelligent Orchestration**
*   **Adaptive Layouts:** tmux dashboard automatically scales from single agent to massive fleets.
*   **Capability-Based Routing:** Conductor selects agents based on their strengths (Coding, Architecture, etc.).
*   **Automated Git Lifecycle:** Isolated branches, auto-commits, and **Review-Pattern** workflows.
*   **Semantic Knowledge Base:** LLM-powered architectural search (`!kb`).
*   **Unified Dashboard (v3.0):** High-density real-time TUI featuring **Fleet Status** and agent progress.
*   **Enhanced Console:** Python-based interactive shell with history and tab-completion.

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

---

## 🛠️ Key Scripts

| Script | Purpose |
|--------|---------|
| `./install.sh --global` | **NEW** - Installs ai-colab globally and adds `ai-colab` command to PATH |
| `scripts/python-env-manager.sh`| **NEW** - Universal environment manager with portable Python support |
| `scripts/workspace_manager.py` | **NEW** - Multi-project Git discovery and registration logic |
| `scripts/console.py` | **NEW** - Enhanced Python-based interactive command console |
| `scripts/quality-gates.sh` | **NEW** - Automated code quality validation (Linting, Security, Syntax) |
| `./launch.sh` | Unified launcher with interactive project and agent selection |
| `scripts/conductor-workflow.sh`| The orchestration heart (Git, KB, Tasking, Capability Routing) |
| `webui/app_refactored.py` | **NEW** - Modular Web UI backend (v3.0) using Flask Blueprints |
| `scripts/message-queue.sh` | **NEW** - SQLite-based message queue with delivery guarantees |

---

## 🌐 Web UI v3.0

ai-colab includes a modular Web UI for professional browser-based management:

### Features
- **Project Switcher**: Seamlessly switch between managed projects from the header.
- **Modular Blueprints**: Decoupled API services for terminal, system, config, and KB.
- **Fleet Health**: Real-time latency, status, and **task progress** for all agents.
- **Knowledge Base**: Semantic search with relevance scores and auto-indexing.
- **Session Persistence**: Automatic recovery of tmux sessions and active configurations.

### New API Endpoints (v3.0)
- `GET /api/workspace/list` - List all registered projects.
- `POST /api/workspace/switch` - Switch active project context.
- `GET /api/status` - Enhanced status including project root and agent progress.
- `POST /api/shutdown` - Graceful shutdown of all agent sessions.

---

## 🧪 Automated Testing

### Quality Gates
The system now enforces strict quality standards before any code is merged:
- ✅ **Python Syntax**: Recursive check via `compileall`.
- ✅ **Linting**: `flake8` verification of coding standards.
- ✅ **Security**: `bandit` scan for common vulnerabilities.
- ✅ **Integration**: Automated merge-validation via `hcom-test-runner.sh`.

### Web UI & Core
- **8 automated tests** covering all v3.0 modular blueprints.
- **Unit tests** for workspace discovery and portable python logic.
- **Real-time feedback** via local file watcher.

**Status:** 8/8 Web UI tests passing ✅ | Quality Gates available ✅ | Multi-Project tests available ✅

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

