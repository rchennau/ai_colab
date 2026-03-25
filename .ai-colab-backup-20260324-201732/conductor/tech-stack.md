# Tech Stack: ai-colab

## Core Orchestration (Project-Agnostic)
*   **Bash/Zsh:** Shell scripting for project automation, installer/launcher, and agent wrappers.
*   **hcom (Hook-Comms):** Unified messaging protocol for real-time agent coordination.
*   **hcom-kv:** Shared blackboard (KV store) for ephemeral project state and task handoffs.
*   **Dashboard:** Unified `tmux`-based dashboard for multi-agent oversight.
*   **Database:** `sqlite3` for local persistent storage (Blackboard & Semantic Index).
*   **Python:** Supporting language for advanced utilities and terminal detection.

## Atari-LX Module (Optional Addon)
*   **6502 Assembly:** Primary language for performance-critical Atari 8-bit routines.
*   **C (cc65):** Used for higher-level application logic and Atari system integration.
*   **Build System:** `cc65` toolchain for Atari target compilation.
*   **MCP (Model Context Protocol):** Specialized Atari development server (`atari-dev-agent`) for 6502 validation and hardware context.
*   **Emulator:** `Atari800` for automated screenshot capture and validation.

## Specialized Agent Roles
*   **Gemini:** Architect & Orchestrator (Project Lead).
*   **Qwen:** Assembly & Hardware Expert (Timing-critical 6502 - active in Atari module).
*   **DeepSeek:** Logic & Optimization Specialist (C and Algorithm optimization).
*   **Claude:** Generalist & Documentation Expert.

