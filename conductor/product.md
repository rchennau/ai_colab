# Product Definition: ai-colab

## Vision
To provide a seamless, multi-agent development environment where different AI agents (Gemini, Claude, Qwen, etc.) can collaborate autonomously or semi-autonomously on complex software engineering tasks.

## Target Audience
AI Engineering teams, open-source contributors, and developers working on multi-agent systems where task orchestration, state synchronization, and collaborative problem-solving are required.

## Core Pillars

### **1. Unified Orchestration**
*   **Conductor Agent:** A dedicated agent that manages the project plan (`tracks.md`) and ensures all other agents are working on the right tasks.
*   **Conflict Resolution:** Mechanisms to prevent overlapping work and ensure file-system integrity across multiple AI editors.

### **2. Frictionless Setup**
*   **Master Installer (`install.sh`):** A single command to set up the entire environment, including `hcom`, `tmux`, and multiple LLM CLIs.
*   **One-Click Launch (`launch.sh`):** A unified interface to start the collaboration session, choosing the desired mix of agents.

### **3. Inter-Agent Intelligence**
*   **hcom Integration:** A robust messaging layer for real-time communication between LLMs.
*   **Shared Blackboard:** A lightweight KV store for sharing ephemeral project state (e.g., current task, performance bottlenecks, shared constants).

### **4. Specialized Domains (Atari-LX)**
*   **High-Performance Context:** Specific tools and prompts for 6502 assembly, Atari hardware constraints, and performance-critical systems.
*   **Automated Debates:** A unique feature to have multiple agents argue the merits of different implementation strategies.

## Roadmap
*   **Phase 1:** Unified Installer & Launcher (Done ✅)
*   **Phase 2:** Deep Blackboard Integration for task handoffs (Done ✅)
*   **Phase 3:** Automated Progress Reporting & QA Automation (Done ✅)
*   **Phase 4:** Multi-Project & Advanced Orchestration (In Progress 🏗️)
