# ai-colab: Multi-Agent Collaboration Framework

A unified environment for coordinating multiple AI agents (Gemini, Claude, Qwen, DeepSeek, NeMo, etc.) on complex engineering projects.

## 🚀 Quick Start

1.  **Clone and Install:**
    ```bash
    git clone https://github.com/rchennau/ai_colab.git
    cd ai_colab
    ./install.sh
    ```
    This script handles all dependencies (hcom, LLM CLIs, tmux, sqlite3, and project-specific tools).

2.  **Launch the Dashboard:**
    ```bash
    ./launch.sh
    ```
    Choose your agents and start collaborating in a unified tmux-based dashboard with real-time status tracking.

## 🏗️ Core Architecture

### **The Conductor**
The **Conductor** is the project's "orchestrator." It maintains the Source of Truth in `conductor/tracks.md`, ensuring all agents are aligned on tasks and project state.

### **hcom (Hook-Comms)**
All agents communicate via [hcom](https://github.com/aannoo/hcom), a message-passing protocol that enables:
*   **Inter-agent messaging:** Agents can "talk" to each other, hand off tasks, and request reviews.
*   **Shared Blackboard:** A lightweight KV store (`hcom-kv`) for sharing state (e.g., current task, progress percentages).
*   **Unified TUI:** Monitor all agents and their messages in a single dashboard.

## 🛠️ Key Scripts

| Script | Purpose |
|--------|---------|
| `./install.sh` | Master installer for dependencies and LLM CLIs. |
| `./launch.sh` | Unified launcher for the Dashboard and Conductor. |
| `scripts/conductor-workflow.sh` | Automated background manager for track progress. |
| `scripts/atari-debate.sh` | Automates technical debates between active agents. |

## 🕹️ Project Context: Atari-LX
This repository is pre-configured for **Atari-LX Engineering**, featuring deep integration with the Atari 8-bit hardware environment, shared constants, and automated technical debates for optimized 6502 assembly development.

## 📝 License
Part of the hcom utilities ecosystem.
