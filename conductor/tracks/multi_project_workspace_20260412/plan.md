# Multi-Project Workspace & Portable Environment Plan

## Background & Motivation
Currently, `ai_colab` is tightly coupled to its own repository structure. To evolve it into a robust developer tool, it must be able to switch among various software projects on the user's environment. This plan introduces a global CLI, multi-project discovery, workspace registry, and an OS-independent Python runtime (via `uv`) to ensure true portability.

## Proposed Solution: Global CLI Model
`ai_colab` will be installed globally (e.g., in `~/.ai-colab`). Running the `ai-colab` CLI anywhere will detect local `.git` repositories and offer to manage them.

## Phase 1: Portable Python Isolation
1.  **Refactor `scripts/python-env-manager.sh`**:
    *   Add a `--portable` flag to bypass system Python entirely.
    *   If `uv` is detected or installed, use `uv python install 3.11` to fetch a standalone Python distribution.
    *   Create isolated `.venv` using `uv venv --python 3.11`.
2.  **Global Installation (`install.sh`)**:
    *   Copy or symlink the `ai_colab` repository into a central `AI_COLAB_HOME` (e.g., `~/.ai-colab`).
    *   Create a global `ai-colab` wrapper script in `~/.local/bin` (or equivalent) that delegates to the hub while preserving the user's `$PWD` as `WORKSPACE_ROOT`.

## Phase 2: Discovery & Workspace Registry
1.  **Develop `scripts/workspace-manager.py`**:
    *   Implement logic to scan a given directory for `.git` subdirectories (max depth 2).
    *   Define a TOML schema for `~/.ai-colab/config/workspace.toml` to store managed projects.
2.  **Launcher Integration (`launch.sh`)**:
    *   Check if `WORKSPACE_ROOT` is registered.
    *   If not registered, trigger the discovery scan.
    *   Prompt the user: "We found the following git repositories. Would you like to manage them with ai_colab?"
    *   Present an interactive menu to select the active project context before launching the dashboard/WebUI.
    *   Register `ai_colab` itself as a managed project.

## Phase 3: WebUI Context Switching
1.  **WebUI Project Navigation**:
    *   Update `webui/index.html` to fetch registered workspaces and populate a "Project Switcher" dropdown.
2.  **Backend Agent Restart**:
    *   Update `webui/api/system.py` to handle context switches.
    *   When switching, update `WORKSPACE_ROOT` in the session state and gracefully restart the conductor and spoke agents via `hcom` commands in the new context.

## Phase 4: QA & Test Harness
1.  **Unit Tests**:
    *   `tests/test_workspace_manager.py`: Mock directory trees to verify `.git` detection and registry read/writes.
2.  **Feature Tests**:
    *   `tests/test_launch_discovery.sh`: Simulate `launch.sh` in an unregistered directory containing mock git repos.
3.  **System Tests**:
    *   `tests/test_global_cli.sh`: Verify the `ai-colab` wrapper correctly forwards `WORKSPACE_ROOT` and uses the portable `uv` Python.
4.  **End-to-End (E2E) Tests**:
    *   `tests/test_webui_context_switch.py` (Playwright): Automate navigating the WebUI, adding a mock project via the UI, switching to it, and verifying the backend agents restart in the correct directory.
