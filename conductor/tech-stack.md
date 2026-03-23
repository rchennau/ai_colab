# Tech Stack: ai-colab

## Core Languages
*   **6502 Assembly:** Primary language for performance-critical Atari 8-bit routines.
*   **C (cc65):** Used for higher-level application logic and Atari system integration.
*   **Bash/Zsh:** Shell scripting for project automation, installer/launcher, and agent wrappers.
*   **Python:** Supporting language for specialized tools (e.g., `nemo-cli.py`).

## Inter-Agent Infrastructure
*   **hcom (Hook-Comms):** Unified messaging protocol for real-time agent coordination.
*   **hcom-kv:** Shared blackboard (KV store) for ephemeral project state and task handoffs.
*   **MCP (Model Context Protocol):** Specialized Atari development server (`atari-dev-agent`) for 6502 validation and hardware context.

## Development Environment
*   **Dashboard:** Unified `tmux`-based dashboard for multi-agent oversight.
*   **Database:** `sqlite3` for local persistent storage.
*   **Build System:** `cc65` toolchain for Atari target compilation.

## Specialized Agent Roles
*   **Gemini:** Architect & Orchestrator (Project Lead).
*   **Qwen:** Assembly & Hardware Expert (Timing-critical 6502).
*   **DeepSeek:** Logic & Optimization Specialist (C and Algorithm optimization).
