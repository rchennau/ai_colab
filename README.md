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
    
    *Note: Zsh users should run `source ~/.zshrc` after the script finishes to enable aliases and path updates.*

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
| `scripts/*-hcom.sh` | Agent wrappers (Gemini, Qwen, vLLM via **ELC**, etc.) with standardized hcom identity and status tracking. |
| `scripts/conductor-workflow.sh` | Automated background manager for track progress and worker spawning. |
| `scripts/atari-debate.sh` | Automates technical debates between active agents (including vLLM Atari expert). |

## 🕹️ Project Context: Atari-LX
This repository is pre-configured for **Atari-LX Engineering**, featuring deep integration with the Atari 8-bit hardware environment, shared constants, and automated technical debates for optimized 6502 assembly development.

## 📝 License
Part of the hcom utilities ecosystem.

## 📋 Best Practices & Troubleshooting

### **Agent Naming (hcom 0.7.5+)**
Always use **lowercase letters, numbers, and underscores** for agent names. Hyphens and uppercase characters are restricted and may cause identity resolution failures (e.g., `gemini_dev` instead of `gemini-dev`). 

### **Agent Pulse (Heartbeats)**
Agent wrappers (`*-hcom.sh`) now include a background pulse loop. This ensures that even idle or interactive agents (like Qwen or vLLM) are not marked as "stale" in the TUI by pulsing `hcom listen` every 60 seconds.

### **Configuration Validation**
If `hcom` warns about an invalid `config.toml`, check for literal `\n` characters or missing `=` signs. Run `hcom status` to verify your configuration is valid.

### **vLLM Integration (via easy-llm-cli)**
For high-performance local inference, the `vllm_dev` agent now uses **easy-llm-cli (ELC)**. This provides a Gemini-like terminal interface while connecting to your local vLLM OpenAI-compatible server.
