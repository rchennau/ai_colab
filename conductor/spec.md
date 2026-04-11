# Track Specification: Console UX Revolution (Phase 17)

## Overview
This track focuses on radically improving the user experience of the `ai-colab` terminal dashboard (launched via `dashboard-launch.sh`). The goal is to make managing large fleets of agents intuitive and scalable by introducing adaptive tmux layouts, a robust interactive console, and persistent status monitoring.

## Goals
1.  **Adaptive tmux Layouts (P2.1)**: Dynamically adjust the tmux layout based on the number of active agents. Support grid, split, and tabbed window layouts.
2.  **Focus Mode (P2.2)**: Allow the user to zoom into a single agent's pane via keyboard shortcuts, hiding the rest of the fleet while maintaining global visibility.
3.  **Enhanced Console (P2.3)**: Replace the basic `read` loop with a robust Python readline-based console offering command history, tab completion, and multi-line support.
4.  **Real-Time Status Bar (P2.4)**: Update the tmux status line dynamically with a color-coded summary of agent health (e.g., green=healthy, yellow=busy, red=stale).
5.  **Session Persistence (P2.5)**: Save the exact tmux layout and agent assignments so that reconnecting restores the exact visual state.

## Requirements
- **Layout Engine**: Refactor `scripts/dashboard-launch.sh` to implement a math-driven layout engine (e.g., 2 agents = split, 3-4 = grid, 5+ = multi-window).
- **Console Script**: Create `scripts/console.py` utilizing the `prompt_toolkit` or `readline` library to communicate with `hcom` and the Conductor.
- **Status Integration**: Enhance `scripts/conductor-workflow.sh` or a new background daemon to regularly push aggregated health data to the tmux status bar.
- **State Management**: Persist layout metadata to `.ai-colab-state.json` or `.ai-colab/tmux-layout.json`.

## Success Criteria
- [ ] Launching with 1-4 agents results in a single-window tiled/grid layout.
- [ ] Launching with 5+ agents automatically organizes them into logical tmux windows (e.g., a "fleet" window).
- [ ] The user can interact with a Python-based console featuring command history (up/down arrows).
- [ ] The tmux status bar clearly displays the health of the fleet in real-time.
- [ ] Detaching and reattaching preserves the custom layout.
