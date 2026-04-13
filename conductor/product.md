# Product Definition: ai-colab

## Vision
To provide a seamless, multi-agent development environment where human oversight and AI autonomy work in harmony. **ai-colab is a self-hosted Orchestration Core (Hub)** that acts as a central controller for remote agents and compute resources.

## 'Hub and Spoke' Architecture
ai-colab follows a modular architecture where the core framework is separated from the intelligence providers:
- **Orchestration Core (Hub)**: Self-hosted (native or Docker). Handles messaging (hcom), state (Blackboard), tasking (Conductor), and monitoring (Dashboard).
- **Remote Agents (Spokes)**: High-power agents (like **nemoclaw**) run externally on specialized infrastructure (NVIDIA API, RunPod, etc.) and connect to the Hub via remote CLIs and MCP.

## Multi-Backend Compute
The Hub connects to various backends for specialized agent deployment:
- **NVIDIA NIM API**: Hosted inference for enterprise-grade models like **nemoclaw**.
- **RunPod / AWS / GCP**: Infrastructure for self-hosting specialized agent containers or model pods.
- **Local Server**: Standard vLLM/Ollama execution for low-latency tasks.

## Core Pillars

### **1. Self-Hosted Hub**
*   **Conductor Agent:** A dedicated orchestrator that manages the project plan (`tracks.md`) and coordinates remote workers.
*   **Orchestration Core Image:** A lightweight Docker image for self-hosting the Hub on any server.
*   **Automated Quality Assurance:** Integrated testing and code reviews that broadcast results to the entire agent network.
*   **Git Lifecycle Automation:** Automated branching and pseudo-PR management across the distributed system.
*   **Web UI Dashboard:** Browser-based interface for configuration, monitoring, and agent management.
*   **Automated Testing:** CI/CD integration with GitHub Actions and local file watcher for real-time test feedback.

### **2. Frictionless Setup**
*   **Master Installer (`install.sh`):** A single command to set up the project-agnostic core and optionally install domain-specific modules.
    *   `--wizard`: Interactive CLI wizard with step-by-step guidance
    *   `--reconfigure`: Modify existing installation
    *   `--auto`: Non-interactive quick install
*   **One-Click Launch (`launch.sh`):** A unified interface to start the collaboration session, choosing the desired mix of agents and active modules.
    *   **Project Migration:** Automatically detects and migrates existing AI/LLM integrations (MCP, conductor, KB) into the ai-colab ecosystem.
*   **Web UI Setup:** Browser-based installation wizard accessible at http://localhost:8080
*   **Docker Compose:** Containerized deployment with persistent volumes and health checks.
*   **Configuration Management:** Centralized config with schema validation, atomic writes, and automatic backups.
*   **Pre-flight Checks:** Automated system readiness verification before launch.

### **3. Inter-Agent Intelligence**
*   **hcom Integration:** A robust messaging layer for real-time communication between LLMs.
*   **Shared Blackboard:** A lightweight KV store for sharing ephemeral project state.
*   **Semantic Knowledge Base:** RAG-lite system for architectural guidance based on the entire codebase.
*   **Agent Health Monitoring:** Real-time status tracking with automatic restart on failure.
*   **Session Recovery:** Automatic cleanup and recovery from crashed sessions.
*   **Enhanced Dashboard (v2.4):** Improved tmux dashboard with pre-flight checks, health monitoring, and better error handling.
*   **80-Column ANSI UI:** Unified CLI aesthetic with professional ANSI graphics, banners, and status tracking across all core scripts.

### **4. Modular Addons (Atari-8bit)**
*   **High-Performance Context:** Specific tools and prompts for 6502 assembly, Atari hardware constraints, and performance-critical systems.
*   **Hardware Visualization:** ASCII-art memory map generator and performance trending dashboards.
*   **Automated Debates:** A unique feature to have multiple agents argue the merits of different implementation strategies (`atari-debate.sh`).

## Roadmap
*   **Phase 1:** Unified Installer & Launcher (Done ✅)
*   **Phase 2:** Deep Blackboard Integration for task handoffs (Done ✅)
*   **Phase 3:** Automated Progress Reporting & QA Automation (Done ✅)
*   **Phase 4:** Multi-Project & Advanced Orchestration (Done ✅)
*   **Phase 5:** Intelligent Context & Shared Memory (Done ✅)
*   **Phase 6:** Unified Command Center & High-Density Monitoring (Done ✅)
*   **Phase 7:** Advanced Knowledge (RAG) & Git Lifecycle Automation (Done ✅)
*   **Phase 8:** Hardware Visualization & Performance Dashboards (Done ✅)
*   **Phase 9:** Dynamic Plugin System & Fleet Orchestration (Done ✅)
*   **Phase 10:** Multi-Backend Compute & CI/CD Automation (Done ✅)
*   **Phase 11:** Enhanced Installation & Launch Experience (Done ✅)
*   **Phase 12:** NVIDIA NIM nemoclaw Integration (Done ✅)
*   **Phase 13:** Automated Testing & CI/CD Integration (Done ✅)
*   **Phase 14:** Python Environment Optimization (Done ✅)
*   **Phase 15:** Multi-Project Workspaces & Portable Environment (Done ✅)
*   **Phase 16: Foundation Hardening** (Done ✅)
    *   **Theme:** "Make it unbreakable"
    *   Message queue layer with delivery guarantees (P1.1) (Done ✅)
    *   Event processing resilience with cursor persistence (P1.2) (Done ✅)
    *   Blackboard schema validation and atomic operations (P1.3) (Done ✅)
    *   Intelligent capability-based agent selection (P1.4) (Done ✅)
    *   Exponential backoff and circuit breaker for agent recovery (P1.5) (Done ✅)
    *   MQTT security hardening with self-hosted broker (P1.6) (Done ✅)
*   **Phase 17: Console UX Revolution** (Done ✅)
    *   **Theme:** "Make it usable at scale"
    *   Dynamic tmux layouts based on active agent count (P2.1) (Done ✅)
    *   Focused agent mode with fleet status bar (P2.2) (Done ✅)
    *   Enhanced readline-based user console (P2.3) (Done ✅)
    *   Real-time per-agent status in tmux status line (P2.4) (Done ✅)
    *   Dashboard session persistence and restore (P2.5) (Done ✅)
*   **Phase 18: Task Orchestration Intelligence** (Done ✅)
    *   **Theme:** "Make it smart"
    *   Capability-based task routing engine (P3.1) (Done ✅)
    *   Multi-agent collaboration patterns (Review, Pair, Chain) (P3.2) (Done ✅)
    *   Structured progress tracking from agents (P3.3) (Done ✅)
    *   Automated quality gates before merge (P3.4) (Done ✅)
    *   Agent performance metrics and optimization (P3.5) (Done ✅)
*   **Phase 19: Ecosystem Expansion** (Done ✅)
    *   **Theme:** "Make it extensible"
    *   Containerized agents with pre-configured environments (P4.1) (Done ✅)
    *   Cloud deployment on AWS/GCP/Azure (P4.2) → (Backlog)
    *   IDE integration (VS Code / Cursor extension) (P4.3) → (Backlog)
    *   Community module marketplace (P4.4) → (Backlog)
    *   Agent evaluation and benchmarking framework (P4.5) (Done ✅)
*   **Phase 20: Strategic Moats** (Done ✅)
    *   **Theme:** "Make it irreplaceable"
    *   Persistent agent memory and context management (P5.2) (Done ✅)
    *   Cost optimization engine with budget alerts (P5.3) (Done ✅)
    *   Full local model integration (Ollama, llama.cpp, vLLM) (P5.1) (Done ✅)
    *   Self-healing orchestration with conductor failover (P5.5) (Done ✅)
    *   Complete audit trail and compliance export (P5.4) → (Backlog)
*   **Phase 21: The Plugin Economy** (Done ✅)
    *   **Theme:** "Community Extensibility"
    *   Standardize the `ai-colab` module manifest (`module.toml`) (Done ✅)
    *   Develop the `ai-colab module install <name>` CLI registry and discovery (Done ✅)
    *   Sandboxed execution environments for third-party plugins (Done ✅)
*   **Phase 22: Federated Intelligence** (DEFERRED)
    *   **Theme:** "Cross-Hub Collaboration"
    *   **Blueprint:** See [`conductor/federated-intelligence-blueprint.md`](./federated-intelligence-blueprint.md)
    *   Hub-to-Hub messaging protocol over secured `hcom` relay
    *   Task negotiation, bidding, and distributed handoff
    *   Federated Fleet Health monitoring across multiple self-hosted hubs
*   **Phase 23: Communication Protocol Optimization** (In Progress 🔄 — 3/4 tasks complete)
    *   **Theme:** "Eliminate context bloat, optimize agent-to-agent communication"
    *   Structured message protocol with 6 message types (status, heartbeat, request, response, error, complete) (P6.1) (Done ✅)
    *   90% message size reduction vs. English-only (20-50 tokens vs. 200-500)
    *   Human-readable summaries auto-generated from structured data
    *   Conductor protocol handler with instant error detection and automated workflow (P6.3) (Done ✅)
*   **Phase 24: Agent Analytics Web UI Integration** (Deferred)
    *   **Theme:** "Visualizing Fleet Efficiency"
    *   Surfacing historical performance metrics from the Blackboard
    *   Real-time aggregation of success rates and task durations
    *   Actionable insights for fleet optimization via the Web UI dashboard
*   **Phase 24: Environment Portability** (Done ✅)
    *   **Theme:** "Zero user environment dependency — fully self-contained"
    *   Local tmux config (`.ai-colab/tmux.conf`) with clean shell (`bash --norc --noprofile`)
    *   Environment setup script (`scripts/ai-colab-env.sh`) for consistent agent execution
    *   RAG installation fixed to use correct Python version (`$PYTHON_CMD -m pip install`)
    *   No dependency on user's `~/.tmux.conf`, `.bashrc`, `.zshrc`, aliases, or environment variables
*   **Phase 25: Conductor Self-Monitoring** (Done ✅)
    *   **Theme:** "The conductor watches its own pulse"
    *   Conductor heartbeat to blackboard every 30s (P25.1) (Done ✅)
    *   Watchdog with auto-restart and exponential backoff (P25.2) (Done ✅)
    *   State recovery after restart (P25.3) (Done ✅)
    *   Secondary agent detection with stale conductor alerting (P25.4) (Done ✅)

## Future Considerations
- Federated Agent Learning (Skill-sharing across distributed fleets).
- Voice & Vision Interaction (Whisper/Vision-aware Conductor).
- Mobile Dashboards for remote monitoring.
- Multi-modal output generation (diagrams, reports, presentations).
