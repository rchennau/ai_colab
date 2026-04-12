# ai-colab: Multi-Agent Collaboration Framework

A unified, **project-agnostic** environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering tasks.

**Latest Release:** Phase 22 In Progress 🔄 — Communication Protocol Optimization (90% message size reduction) + Environment Portability (fully self-contained, zero user environment dependency).

## 🌟 Vision
To provide a seamless development experience where human oversight and AI autonomy work in harmony. ai-colab handles the "plumbing" of multi-agent systems—messaging, state synchronization, task tracking, and lifecycle management—allowing you to focus on the engineering. **Now with full local LLM support for zero-cloud deployments.**

## 🚀 Quick Start

### Installation (Default: Global CLI)

ai-colab is designed to be installed once and used across all your projects.

```bash
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab
./install.sh
```

**During installation, you will be prompted to:**
1.  **Select Install Type:** Global (Central hub in `~/ai_colab`) or Local (Current folder).
2.  **Choose Directory:** Customize where the hub is installed (defaults to `~/ai_colab`).

### Standardized Logging

For reliability and troubleshooting, all install and launch events are captured in standard Linux log locations:
- **Install Logs:** `~/.local/state/ai-colab/install.log`
- **Launch Logs:** `~/.local/state/ai-colab/launch.log`

### Alternative Pathways

#### **Option 2: Docker & Web UI**

Browser-based setup and containerized management:

```bash
docker-compose up -d
```

Then open: http://localhost:8080

#### **Option 3: Quick/Auto Install (Non-interactive)**

```bash
./install.sh --auto
```

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

**Dashboard Features:**
- **Dynamic Layouts:** Auto-adapts to agent count (1-2: side-by-side, 3-4: grid, 5-7: tabbed, 8+: compact)
- **Focus Mode:** `Ctrl+b f` to zoom single agent pane, `Ctrl+b 1-9` to switch between agents
- **Real-Time Status Bar:** Color-coded fleet status in tmux status line (✓ ready, ⏳ busy, ✗ crashed)
- **Enhanced Console:** Python readline-based interface with command history, tab completion, and help
- **Session Persistence:** Auto-saves layout on creation, restore with `bash scripts/restore-layout.sh`
- **Named Layout Presets:** Save/restore layouts as `default`, `coding`, `review`, or custom names

**Agent Memory (P5.2):**
- Persistent conversation history across agent restarts
- Configurable context window (max messages or bytes)
- Automatic compression of old conversations into summaries
- Usage: `bash scripts/agent-memory.sh save/load/compress/status --agent gemini`

**Cost Optimization (P5.3):**
- Per-agent token tracking with cost estimation
- Monthly budget caps with automatic alerts (50%, 75%, 90%, 100%)
- Cost efficiency ranking for intelligent routing
- Usage: `bash scripts/cost-tracker.sh record/status/report/set-budget --agent gemini`

**Conductor Failover (P5.5):**
- Automatic health monitoring and restart on failure
- Exponential backoff (10s → 30s → 60s → 120s) with max 5 attempts
- Agent promotion to temporary conductor when restart fails
- Usage: `bash scripts/conductor-failover.sh monitor/check/restart/promote/status`

**Local LLM Support (P5.1):**
- 8 pre-configured models across 3 runtimes (Ollama, llama.cpp, local vLLM)
- Model download, health checks, and task-based recommendations
- Zero-cloud deployment — run ai-colab with no external API keys
- Usage: `bash scripts/local-models.sh list/download/health/recommend --task coding`

**Environment Portability (P6.2):**
- Fully self-contained — zero dependency on user's `~/.tmux.conf`, `.bashrc`, or aliases
- Local tmux config at `.ai-colab/tmux.conf` with clean shell (`bash --norc --noprofile`)
- Environment setup script (`scripts/ai-colab-env.sh`) for consistent agent execution
- RAG installation now uses correct Python version (`$PYTHON_CMD -m pip install`)

**Structured Communication Protocol (P6.1):**
- 6 message types: status, heartbeat, request, response, error, complete
- 90% message size reduction vs. English-only (20-50 tokens vs. 200-500)
- Human-readable summaries auto-generated from structured data
- Usage: `bash scripts/protocol-encoder.sh status --track my-track --pct 45 --step "coding"`
- Decode: `echo '{"v":1,"t":"status","a":"gemini","pct":45}' | python3 scripts/protocol-decoder.py`

**Module System v2.0 (Phase 21 Complete ✅):**
- **Standardized Schema:** Formalized `module.toml` with versioning, author, dependencies, and permissions.
- **Deep Validation:** Manifests are strictly validated against `config/module.schema.json`.
- **Module Marketplace:** Discover and install community plugins via `ai-colab` (Choice 4).
- **Sandboxed Execution:** Every module runs in its own isolated `uv` virtual environment.
- **Security First:** Explicit permission review (network, disk, env) during installation.
- **Registry Management:** Maintainers can manage the index via `scripts/registry-manager.py`.

**Multi-Project Support:**
Running `ai-colab` will scan for local git repositories and allow you to register and switch between them seamlessly.

### Testing & Quality Gates

Ensure code integrity with the built-in quality assurance framework:

```bash
# Run all quality gates (Linting, Security, Syntax)
./scripts/quality-gates.sh

# Validate all module manifests against the schema
python3 scripts/module-manager.py validate-all

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
| `scripts/message-queue.sh` | **NEW** - SQLite-based message queue with delivery guarantees |
| `scripts/memory-manager.py` | **NEW** - Agent conversation history with compression |
| `scripts/agent-memory.sh` | **NEW** - Shell wrapper for agent memory management |
| `scripts/budget-manager.py` | **NEW** - Token tracking and cost estimation |
| `scripts/cost-tracker.sh` | **NEW** - Shell wrapper for budget management |
| `scripts/conductor-failover.sh` | **NEW** - Conductor health monitoring and auto-restart |
| `scripts/agent-benchmark.sh` | **NEW** - Agent performance benchmarking framework |
| `scripts/benchmark-runner.py` | **NEW** - Python benchmark execution engine |
| `scripts/local-models.sh` | **NEW** - Local LLM model management shell wrapper |
| `scripts/model-manager.py` | **NEW** - Local model registry, download, and recommendation engine |
| `webui/app_refactored.py` | **NEW** - Modular Web UI backend (v3.0) using Flask Blueprints |

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

### Comprehensive Test Harness
ai-colab includes a comprehensive test suite with **200+ tests** across all phases:

| Phase | Tests | Coverage |
|-------|-------|----------|
| **Phase 16: Foundation Hardening** | 148 | Message queue, event cursor, blackboard schema, agent selection, circuit breaker, MQTT security |
| **Phase 17: Console UX Revolution** | 50 | Dynamic layouts, focus mode, enhanced console, status bar, session persistence |
| **Phase 19: Ecosystem Expansion** | 30 | Docker deployment, agent benchmarking |
| **Phase 20: Strategic Moats** | 68 | Local LLM support (28), agent memory (12), cost optimization (14), conductor failover (9) |

**Status:** 300+ tests passing ✅ | Module Schema Validated ✅ | Quality Gates available ✅ | Multi-Project tests available ✅

### Running Tests

```bash
# Run all tests
bash scripts/test-all.sh

# Run specific test suite
bash tests/test_local_models.sh        # Local LLM Support (28 tests)
bash tests/test_agent_memory.sh        # Agent Memory (12 tests)
bash tests/test_cost_tracker.sh        # Cost Optimization (14 tests)
bash tests/test_conductor_failover.sh  # Conductor Failover (9 tests)
```

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

