# Tech Stack: ai-colab

## Core Orchestration (Project-Agnostic)
*   **Bash/Zsh:** Shell scripting for project automation, installer/launcher, and agent wrappers.
*   **hcom (Hook-Comms):** Unified messaging protocol for real-time agent coordination.
*   **hcom-kv:** Shared blackboard (KV store) for ephemeral project state and task handoffs.
*   **Dashboard:** Unified `tmux`-based dashboard for multi-agent oversight.
*   **Database:** `sqlite3` for local persistent storage (Blackboard & Semantic Index).
*   **Python:** Supporting language for advanced utilities and terminal detection.

## Modular Addons (Example: Atari-8bit)
*   **Domain-Specific Languages:** Support for 6502 Assembly, C (cc65), etc.
*   **Custom Tooling:** Manifest-driven integration of specialized profilers and debuggers.
*   **Compute Spoke Integration:** Specialized MCP servers for domain-specific hardware context.
*   **Visual Debugging:** Integrated support for emulator screenshots and state validation.

## Specialized Agent Roles
*   **Gemini:** Architect & Orchestrator (Project Lead).
*   **Qwen:** Assembly & Hardware Expert (Timing-critical code - active in modular addons).
*   **DeepSeek:** Logic & Optimization Specialist (C and Algorithm optimization).
*   **Claude:** Generalist & Documentation Expert.

