# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-04-11 (Phase 21: Plugin Economy Complete)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher with **three launch modes** (Dashboard, WebUI, Debug) and **module enablement** (`-m/--module` flag). Auto-activates virtual environment. Supports **multi-project discovery**, global CLI model, and **modular marketplace access**.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, `--auto`, and **`--global`** modes. **Auto-detects Python environment** (uv → conda → venv → system) and creates virtual environment in `.venv/`.
- `scripts/module-marketplace.sh`: **NEW (P21.3)** - Discovery and installation CLI for community modules. Supports searching, info extraction, and remote installation.
- `scripts/registry-manager.py`: **NEW (P21.2)** - Helper for maintainers to manage the central module `index.json`.
- `scripts/module-manager.py`: Updated (P21.1) - Now includes **deep manifest validation** against `config/module.schema.json` and metadata info extraction.
- `scripts/module-manager.sh`: Updated (P21.4) - New **`run` command** that automatically detects and uses module-specific isolated virtual environments.
- `config/module.schema.json`: **NEW (P21.1)** - Standardized JSON schema for module manifests, including versioning, dependencies, and permissions.
- `registry/index.json`: **NEW (P21.2)** - Canonical registry index for community plugin discovery.
- `scripts/console.py`: Enhanced Python-based interactive command console with history, tab-completion, and multi-line support.
- `scripts/quality-gates.sh`: Automated code quality validation framework (Linting, Security, Syntax) integrated into the merge workflow.
- `scripts/agent-benchmark.sh`: Standardized agent evaluation framework. Compares LLM performance across coding, reasoning, and architecture tasks.
- `scripts/python-env-manager.sh`: Universal Python environment manager. Detects uv, conda, venv, pixi, and pyenv. Supports **standalone portable Python distributions** via `uv python install`.
- `scripts/workspace_manager.py`: Logic for scanning directories for Git repositories and managing the global `workspace.json` registry.
- `scripts/message-queue.sh`: SQLite-based message queue layer providing **reliable message delivery**, offline queuing, and exponential backoff retry.
- `scripts/utils.sh`: Shared utilities including 80-column ANSI UI helpers, **Health 2.0** reporting, **blackboard schema validation**, **intelligent agent selection**, **agent analytics logging**, and **progress reporting**.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Includes **capability-based routing**, **multi-agent collaboration patterns (Review Pattern)**, **real-time tmux status bar updates**, and an **Autonomous Fleet Watchdog**.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring. Features a **Fleet Status** section with **real-time agent progress and task steps**.
- `scripts/dashboard-launch.sh`: Enhanced dashboard launcher (v3.0) with **adaptive tmux layouts (grid/overflow)**, **focus mode**, and **session configuration persistence**.
- `webui/app_refactored.py`: Modular Flask-based API server (v3.0) using blueprints for core services (terminal, system, config, kb, models).
- `webui/index.html`: Single-page application featuring **xterm.js web terminals**, **multi-project switcher**, real-time monitoring, and module configuration.
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`. Includes **Docker support (P19.1)** for containerized agent isolation, **real-time stdout parsing for progress tracking**, and **performance analytics logging**.

## AI Agent Integration (Spokes)
- `docker/agents/`: Collection of specialized agent images (Gemini, Claude, Qwen, DeepSeek) for reproducible distributed execution.
- `scripts/build-agent-images.sh`: Unified build system for the agent Docker fleet.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.
- `system-prompts/`: High-power role definitions for Gemini, Qwen, DeepSeek, and nemoclaw.

## Testing & Quality Assurance
- `tests/test_container_agents.sh`: Verification harness for the containerized agent isolation system.
- `tests/test_webui.sh`: Comprehensive Web UI test suite (8 automated tests).
- `tests/test_workspace_manager.py`: Unit tests for git repository discovery and registry management.
- `tests/test_portable_python.sh`: Verification of `uv` standalone Python isolation logic.
- `tests/test_python_env_optimization.sh`: Integration tests for the universal environment manager.
- `scripts/test-launch-options.sh`: v3.0 Launch and Architecture Test harness.

## Index Metadata
- Status: Active
- Source: Milestone 24 Architectural Review
- Latest Enhancements: **Web UI v3.0**, **Console UX Revolution**, **Task Orchestration Intelligence**, **Quality Gates**, **Containerized Agents**, **Plugin Economy (Marketplace & Sandboxing)**
