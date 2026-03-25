# Product Definition: ai-colab

## Vision
To provide a seamless, multi-agent development environment where human oversight and AI autonomy work in harmony. **ai-colab is a self-hosted Orchestration Core (Hub)** that acts as a central controller for remote agents and compute resources.

## 'Hub and Spoke' Architecture
ai-colab follows a modular architecture where the core framework is separated from the intelligence providers:
- **Orchestration Core (Hub)**: Self-hosted (native or Docker). Handles messaging (hcom), state (Blackboard), tasking (Conductor), and monitoring (Dashboard).
- **Remote Agents (Spokes)**: High-power agents (like **nemoclaud**) run externally on specialized infrastructure (NVIDIA API, RunPod, etc.) and connect to the Hub via remote CLIs and MCP.

## Multi-Backend Compute
The Hub connects to various backends for specialized agent deployment:
- **NVIDIA NIM API**: Hosted inference for enterprise-grade models like **nemoclaud**.
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

### **4. Modular Addons (Atari-LX)**
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
    *   Interactive CLI Wizard with step-by-step guidance
    *   Web UI for browser-based management (Flask backend)
    *   Docker Compose deployment with persistent volumes
    *   Configuration schema validation and atomic writes
    *   Reconfiguration mode (--reconfigure flag)
    *   Pre-flight checks for system readiness
    *   Session recovery and health monitoring
    *   **Project Migration Tool:** Automated import of existing AI configurations
    *   **80-Column ANSI UI:** Professional CLI graphics and status reporting
*   **Phase 12:** NeMo-Claude (nemoclaw) NVIDIA Integration (Done ✅)
*   **Phase 13:** Automated Testing & CI/CD Integration (Done ✅)
    *   GitHub Actions workflow for Web UI testing
    *   Local file watcher for automated test execution
    *   8 comprehensive Web UI API tests
    *   Real-time test feedback during development
    *   Test status badges and artifact upload

## Future Considerations
- Native IDE Integration (VS Code / Cursor Extension).
- Advanced Fleet Autonomy (Self-healing remote workers).
- Voice & Vision Interaction (Whisper/Vision-aware Conductor).
- Mobile Dashboards for remote monitoring.
- Federated Agent Learning (Skill-sharing across distributed fleets).
