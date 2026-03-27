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

## 🆕 New: MCP Server & RAG System

ai-colab now includes a **hybrid intelligence layer** for enhanced LLM integration and semantic search:

### **MCP Server (Model Context Protocol)**
Standardized tool access for LLM-CLIs and IDE integration:
- **12 MCP Tools**: blackboard, tracks, knowledge, agents, DevOps
- **Transports**: stdio (LLM-CLI) + SSE (web clients)
- **IDE Support**: VS Code, Cursor, gemini-cli, qwen-code

```bash
# Setup LLM-CLI integration
./scripts/setup-mcp-clients.sh --all

# Start MCP server
python -m mcp.ai_colab_server
```

### **RAG System (Semantic Search)**
Retrieval-Augmented Generation for codebase understanding:
- **Semantic Search**: Find relevant docs by meaning, not keywords
- **Auto-Refresh**: File watcher for automatic re-indexing
- **Query Caching**: Fast repeated searches

```bash
# Search knowledge base
./scripts/hcom-kb-search.sh "How does the blackboard work?"

# Launch with auto-indexing
./launch.sh --rag-watcher
```

### **Web UI Knowledge Base**
Browser-based semantic search interface:
- Search with relevance scores
- Filter by source (conductor, tracks, docs)
- Index management and statistics

Access at: http://localhost:8080 → Knowledge Base tab

📖 **Guide:** See [`docs/MCP_RAG_USER_GUIDE.md`](docs/MCP_RAG_USER_GUIDE.md)

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
*   **Fleet Autonomy & Self-Healing:** Autonomous watchdog that monitors agent health and recovers from crashes.
*   **Automated Git Lifecycle:** Isolated branches, auto-commits, and pseudo-PRs.
*   **Semantic Knowledge Base:** LLM-powered architectural search (`!kb`).
*   **Unified Dashboard (v3.0):** High-density real-time TUI featuring **Fleet Health** monitoring.
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
| `./launch.sh --rag-watcher` | Launch with RAG file watcher for auto-indexing |
| `./scripts/migrate-project.sh` | Project Detection & Migration Tool (automated AI import) |
| `./scripts/setup-mcp-clients.sh` | MCP client setup for gemini-cli, qwen-code, claude-code |
| `./scripts/hcom-kb-search.sh` | Enhanced !kb command with semantic search |
| `./scripts/run-tests.sh` | Test runner for MCP, RAG, integration, security |
| `./scripts/verify-integration.sh` | Integration verification script |
| `scripts/config-manager.sh` | Central configuration management and schema validation |
| `scripts/install-wizard.sh` | Interactive terminal-based configuration wizard |
| `scripts/utils.sh` | Shared utilities and 80-column ANSI UI helpers |
| `scripts/agent-wrapper.sh` | Unified registration, heartbeats, and role injection |
| `scripts/conductor-workflow.sh`| The orchestration heart (Git, KB, Tasking) |
| `scripts/hcom-test-runner.sh` | Unified test execution and blackboard reporting |
| `scripts/hcom-kb-index.sh` | Generates the semantic project map for `!kb` |
| `scripts/conductor-dashboard.sh`| Renders the high-density terminal dashboard (v2.4) |
| `scripts/dashboard-launch.sh` | Enhanced dashboard launcher (v2.4) with pre-flight checks and cross-version tmux compatibility |
| `webui/app.py` | Flask-based Web UI and API backend (v2.1 with KB endpoints) |
| `tests/test_webui.sh` | Automated Web UI test suite (8 tests) |
| `scripts/webui-test-watch.sh` | Local file watcher for automated testing |
| `mcp/ai_colab_server/` | MCP server with 12 tools for LLM-CLI integration |
| `rag/` | RAG system for semantic search and auto-indexing |

---

## 🌐 Web UI

ai-colab includes a comprehensive Web UI for browser-based management:

### Features
- **Setup Wizard**: Interactive 5-step configuration via browser
- **Dashboard**: Real-time system status with health monitoring
- **Fleet Health**: Real-time latency and status for distributed spokes (NEW!)
- **Knowledge Base**: Semantic search with relevance scores
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

### New API Endpoints (v2.1)
- `GET /health` - Enhanced health with tmux/hcom/disk checks
- `GET /api/preflight` - Pre-flight checks (mirrors CLI)
- `GET /api/session/status` - tmux session monitoring
- `POST /api/session/recover` - Session recovery
- `GET /api/agents` - Real-time agent list
- `POST /api/dashboard/launch` - Launch dashboard from browser
- **`GET /api/kb/search`** - Semantic knowledge base search (NEW!)
- **`POST /api/kb/index`** - Trigger document indexing (NEW!)
- **`GET /api/kb/stats`** - Get index statistics (NEW!)

### Knowledge Base Page
Access at: http://localhost:8080 → Knowledge Base tab
- Search by semantic meaning (not just keywords)
- Filter by source (conductor, tracks, docs, etc.)
- View relevance scores and excerpts
- Trigger re-indexing and view statistics

**Access**: http://localhost:8080 (when running via Docker)

📖 **Guide:** See [`docs/WEBUI_GUIDE.md`](docs/WEBUI_GUIDE.md)
📖 **Testing:** See [`docs/AUTOMATED_WEBUI_TESTING.md`](docs/AUTOMATED_WEBUI_TESTING.md)
📖 **MCP/RAG:** See [`docs/MCP_RAG_USER_GUIDE.md`](docs/MCP_RAG_USER_GUIDE.md)

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
- ✅ Fleet Autonomy & Recovery (Watchdog)
- ✅ Frontend HTML verification

### MCP & RAG Test Suite (NEW!)
- **Unit tests** for all 12 MCP tools
- **Unit tests** for RAG components (chunker, embedder, retriever)
- **Integration tests** for end-to-end functionality
- **Security audit** for vulnerabilities
- **Performance benchmarks** for latency and throughput

### Run MCP & RAG Tests
```bash
# Run all tests
./scripts/run-tests.sh --all

# Run specific test suites
./scripts/run-tests.sh --unit        # Unit tests
./scripts/run-tests.sh --integration # Integration tests
./scripts/run-tests.sh --security    # Security audit
./scripts/run-tests.sh --benchmarks  # Performance benchmarks

# Verify integration
./scripts/verify-integration.sh
```

**Status:** 8/8 Web UI tests passing ✅ | MCP & RAG tests available ✅

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

