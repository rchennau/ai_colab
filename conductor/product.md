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

### **2. Frictionless Setup**
*   **Master Installer (`install.sh`):** A single command to set up the project-agnostic core and optionally install domain-specific modules.
*   **One-Click Launch (`launch.sh`):** A unified interface to start the collaboration session, choosing the desired mix of agents and active modules.

### **3. Inter-Agent Intelligence**
*   **hcom Integration:** A robust messaging layer for real-time communication between LLMs.
*   **Shared Blackboard:** A lightweight KV store for sharing ephemeral project state.
*   **Semantic Knowledge Base:** RAG-lite system for architectural guidance based on the entire codebase.

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
*   **Phase 11:** NeMo-Claude (nemoclaw) NVIDIA Integration (Active 🚀)

## Future Considerations
- Native IDE Integration (VS Code / Cursor Extension).
- Advanced Fleet Autonomy (Self-healing remote workers).
- Voice & Vision Interaction (Whisper/Vision-aware Conductor).
- Mobile Dashboards for remote monitoring.
- Federated Agent Learning (Skill-sharing across distributed fleets).
