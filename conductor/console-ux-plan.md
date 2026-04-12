# Console UX Revolution (Phase 17) Implementation Plan

## Background & Motivation
Managing large fleets of agents inside a terminal requires a sophisticated interface. The current `dashboard-launch.sh` hardcodes a simple split layout that becomes unreadable with more than 4 agents. Furthermore, the user command console uses a basic `read` loop, lacking history, autocomplete, or advanced terminal features.

## Phase 17.1: Adaptive tmux Layouts (P2.1 & P2.5)
1. **Dynamic Layout Engine**:
   * Refactor `scripts/dashboard-launch.sh` to count the requested agents.
   * **1-2 Agents**: Standard side-by-side or vertical split.
   * **3-4 Agents**: 2x2 grid using `tmux select-layout tiled`.
   * **5+ Agents**: Create a primary "dashboard" window with 4 core agents, and a secondary "fleet" window for the overflow agents.
2. **Session Persistence**:
   * Save the layout geometry using `tmux list-panes -F` to a `.ai-colab-state.json` key.
   * Implement a `--restore` flag to rebuild the exact layout upon reconnection.

## Phase 17.2: Enhanced Interactive Console (P2.3)
1. **Python Console (`scripts/console.py`)**:
   * Replace the Bash `while true; read` loop with a Python script.
   * Utilize `readline` or `prompt_toolkit` for command history (up/down arrows).
   * Implement basic tab-completion for core commands (`!status`, `!test`, `!kb`, etc.).
   * Support multi-line input and streaming output pagination.

## Phase 17.3: Real-Time Status Bar & Focus Mode (P2.2 & P2.4)
1. **Status Bar Integration**:
   * Enhance `scripts/conductor-workflow.sh` to extract the `fleet_health` data and format it into a concise string.
   * Periodically push this string to the `tmux` global status-right option: `tmux set-option -g status-right "[✓ Gemini] [⏳ Qwen] [✗ Claude]"`.
2. **Focus Mode**:
   * Document and configure `tmux resize-pane -Z` (Ctrl+B z) as the primary focus mode.
   * Configure tmux bindings to allow quick switching between agents (e.g., `Ctrl+B 1-9` for panes).

## Timeline
- **Phase 17.1**: Implement adaptive layout logic in `dashboard-launch.sh`.
- **Phase 17.2**: Develop `scripts/console.py` and replace the bash console.
- **Phase 17.3**: Status bar integration via `conductor-workflow.sh`.
