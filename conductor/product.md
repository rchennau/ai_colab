# Product Definition: ai-colab

## Vision
To provide a seamless, multi-agent development environment where different AI agents (Gemini, Claude, Qwen, etc.) can collaborate autonomously or semi-autonomously on complex software engineering tasks. **ai-colab is a self-hosted framework** that can be containerized for local use or deployed to any Docker-capable server (RunPod, AWS, GCP).

## Multi-Backend Compute
While the ai-colab core is self-hosted, it supports connecting to specialized compute backends for high-power agent deployment (specifically for **nemoclaud** or other large-scale models):
- **NVIDIA NIM API**: Hosted inference for enterprise models.
- **RunPod**: On-demand GPU infrastructure for containerized agent scaling.
- **Local Server**: Standard vLLM/Ollama local execution.

## Core Pillars

### **1. Self-Hosted Orchestration**
*   **Conductor Agent:** A dedicated agent that manages the project plan (`tracks.md`) and ensures all other agents are working on the right tasks.
*   **Container Ready:** A unified Docker image for self-hosting the entire framework on any infrastructure.
*   **Automated Quality Assurance:** Integrated testing (`hcom-test-runner.sh`) and code reviews (`hcom-code-review.sh`) broadcast results via `hcom`.
*   **Git Lifecycle Automation:** Automated branching, commit validation, and pseudo-PR management.

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
*   **Phase 10:** Multi-Backend Compute & CI/CD Automation (Active 🚀)

## Future Considerations
- Full emulator integration with live-state debugging.
- Cross-platform build support for non-Atari 8-bit targets.
- Voice-command interface for the Conductor dashboard.
- LLM-native IDE integration (VS Code extension).
- Autonomous Project Evolution (Agents proposing their own milestones).
- Federated Agent Learning (Sharing skills across distributed fleets).
