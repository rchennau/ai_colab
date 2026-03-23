# Product Guidelines: ai-colab

## Prose Style & Communication
*   **Technical Precision:** All documentation and agent communication should be concise and technically accurate.
*   **HCOM First:** Use the `hcom` protocol for all inter-agent signaling and state updates.
*   **Documentation as Code:** Keep the `conductor/` directory as the source of truth for project state and tracks.

## Architectural Principles
*   **Multi-Agent Modularity:** Design components that can be independently audited or modified by specialized agents (e.g., Qwen for 6502 assembly, DeepSeek for C logic).
*   **Shared State:** Leverage the `hcom-kv` blackboard for ephemeral project state to minimize file-system contention.
*   **Hardware Alignment:** Prioritize code that respects Atari 8-bit hardware constraints (memory maps, cycle counts, interrupt safety).

## Development Workflow
*   **Automated Verification:** Every track should include automated validation steps (e.g., `cc65` compilation checks).
*   **Safe Experimentation:** Use the `scripts/` wrappers to ensure consistent agent identity and heartbeat monitoring.
*   **Collaborative Debates:** Use the `atari-debate.sh` script to resolve architectural disagreements between agents.

## User Experience
*   **Unified Interface:** Maintain the `launch.sh` dashboard as the primary entry point for human oversight.
*   **Transparent Execution:** Ensure all agent actions are logged and visible within the `hcom` TUI for real-time monitoring.
