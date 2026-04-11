# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-04-10 (Multi-Project & Foundation Hardening)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher with **three launch modes** (Dashboard, WebUI, Debug) and **module enablement** (`-m/--module` flag). Auto-activates `.venv` virtual environment. Supports **multi-project discovery** and global CLI model.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, `--auto`, and **`--global`** modes. **Auto-detects Python environment** (uv → conda → venv → system) and creates virtual environment in `.venv/`.
- `.venv/`: **Auto-created** virtual environment for Python dependencies. Activated by all project scripts.
- `scripts/python-env-manager.sh`: **NEW** - Universal Python environment manager. Detects uv, conda, venv, pixi, and pyenv. Supports **standalone portable Python distributions** via `uv python install`.
- `scripts/workspace_manager.py`: **NEW** - Logic for scanning directories for Git repositories and managing the global `workspace.json` registry.
- `scripts/message-queue.sh`: **NEW** - SQLite-based message queue layer providing **reliable message delivery**, offline queuing, and exponential backoff retry logic.
- `scripts/install-wizard.sh`: Interactive terminal-based configuration wizard (5-step guided setup). Enhanced with 80-column ANSI UI.
- `scripts/migrate-project.sh`: Project Detection & Migration Tool. Automatically imports existing AI integrations.
- `scripts/utils.sh`: Shared utilities including 80-column ANSI UI helpers and **Health 2.0** reporting logic (`report_health`, `get_ms`).
- `scripts/config-manager.sh`: Unified configuration management with validation against `config/config.schema.json`.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Includes an **Autonomous Fleet Watchdog** for stale agent detection and recovery.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring. Features a **Fleet Health** section for spoke monitoring.
- `scripts/dashboard-launch.sh`: Enhanced dashboard launcher (v2.4) with pre-flight checks, session recovery, and dynamic module initialization.
- `scripts/debug-mode.sh`: Debug mode wrapper that loads project context (product.md, tech-stack.md, KB) for focused LLM troubleshooting sessions with KB/RAG integration.
- `scripts/test-launch-options.sh`: Comprehensive test harness with 58 automated tests for all launch options (Dashboard, WebUI, Debug Mode).
- `scripts/module-manager.sh`: Module management with enable/disable commands for WebUI and CLI integration.
- `webui/app_refactored.py`: **NEW** - Modular Flask-based API server (v3.0) using blueprints for core services (terminal, system, config, kb, models).
- `webui/index.html`: Single-page application featuring **xterm.js web terminals**, setup wizards, real-time monitoring, tabbed terminal interface, module configuration, and **multi-project switcher**.
- `scripts/module-manager.py`: Logic for discovering, parsing, and loading module configurations with enable/disable support.
- `Dockerfile`: Containerizes the Orchestration Hub and Web UI with optimized dependencies.
- `docker-compose.yml`: Multi-service orchestration for the Hub, Web UI, and optional local LLM backends (vLLM).
- `docker/entrypoint.sh`: Container initialization with health checks and first-run detection.

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection. Supports `nemoclaw`, NVIDIA NIM, and local vLLM backends. Includes automatic restart logic.
- `scripts/nemoclaw-hcom.sh`: Specific spoke for the NVIDIA NIM nemoclaw architectural lead.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.
- `system-prompts/`: High-power role definitions for Gemini, Qwen, DeepSeek, and nemoclaw.

## Modular Addons
- `modules/atari-8bit/`: Specialized module for 6502 assembly and Atari hardware engineering.
  - `modules/atari-8bit/module.toml`: Manifest defining Atari-specific commands and dashboards.
  - `modules/atari-8bit/scripts/`: Performance profilers, memory map generators, and visual sync tools.
- `modules/nemoclaw/`: Spoke-specific addon for architectural review and status monitoring.

## CI/CD & Deployment
- `scripts/cicd-build.sh`: Builds the self-hosted Hub container image.
- `scripts/cicd-deploy-runpod.sh`: Deploys specialized 'Spoke' compute environments to RunPod.
- `scripts/cicd-deploy-nvidia.sh`: Integration and verification for NVIDIA NIM/API hosted spokes.
- `.github/workflows/webui-tests.yml`: GitHub Actions workflow for automated Web UI testing on push/PR.
- `scripts/webui-test-watcher.py`: Python file watcher for local automated testing during development.
- `scripts/webui-test-watch.sh`: Bash launcher for the file watcher with dependency management.

## Testing & Quality Assurance
- `tests/test_webui.sh`: Comprehensive Web UI test suite (8 automated tests).
- `tests/test_workspace_manager.py`: **NEW** - Unit tests for git repository discovery and registry management.
- `tests/test_portable_python.sh`: **NEW** - Verification of `uv` standalone Python isolation logic.
- `tests/test_python_env_optimization.sh`: **NEW** - Integration tests for the universal environment manager.
- `tests/test_dashboard_fixes.sh`: Dashboard launcher verification tests.
- `tests/test_config_manager.sh`: Automated test suite for the unified configuration foundation.
- `tests/test_install_wizard.sh`: Integration tests for the interactive installer and CLI experience.
- `tests/test_fleet_autonomy.sh`: Verification of Health 2.0 metrics and Blackboard reporting.
- `tests/test_fleet_recovery.sh`: End-to-end simulation of agent crash detection and Watchdog recovery.
- `tests/test_module_hooks.sh`: Verification of dynamic periodic hooks and manifest parsing.
- `scripts/run-tests.sh`: MCP & RAG test runner.

## Documentation
- `docs/INSTALLATION.md`: Comprehensive installation guide.
- `PYTHON_ENV_SETUP.md`: Python environment setup guide with troubleshooting tips.
- `docs/WEBUI_GUIDE.md`: Complete Web UI user guide with API reference.
- `docs/AUTOMATED_WEBUI_TESTING.md`: Guide for automated testing setup and usage.
- `conductor/tracks/multi_project_workspace_20260412/`: Milestone 19 implementation track.
- `conductor/tracks/python_env_optimization_20260411/`: Milestone 18 implementation track.

## Index Metadata
- Status: Active
- Source: Milestone 17, 18 & 19 Architectural Review
- Latest Enhancements: **Web UI v3.0**, **Portable Python**, **Multi-Project Workspaces**, **Message Queue Foundation**
