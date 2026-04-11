# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-04-10 (Phase 17: Console UX Revolution Complete ✅)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher with **three launch modes** (Dashboard, WebUI, Debug) and **module enablement** (`-m/--module` flag). Auto-activates `.venv` virtual environment. Supports **multi-project discovery** and global CLI model.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, `--auto`, and **`--global`** modes. **Auto-detects Python environment** (uv → conda → venv → system) and creates virtual environment in `.venv/`.
- `scripts/console.py`: **NEW (P17.3)** - Enhanced Python-based interactive command console with history, tab-completion, and multi-line support.
- `scripts/update-status-bar.sh`: **NEW (P17.4)** - Real-time fleet status bar updater for tmux status line (20s interval).
- `scripts/save-layout.sh`: **NEW (P17.5)** - Saves tmux session layout to JSON for later restoration.
- `scripts/restore-layout.sh`: **NEW (P17.5)** - Restores tmux session layout from saved JSON preset.
- `scripts/quality-gates.sh`: Automated code quality validation framework (Linting, Security, Syntax) integrated into the merge workflow.
- `scripts/python-env-manager.sh`: Universal Python environment manager. Detects uv, conda, venv, pixi, and pyenv. Supports **standalone portable Python distributions** via `uv python install`.
- `scripts/workspace_manager.py`: Logic for scanning directories for Git repositories and managing the global `workspace.json` registry.
- `scripts/message-queue.sh`: SQLite-based message queue layer providing **reliable message delivery**, offline queuing, and exponential backoff retry.
- `scripts/utils.sh`: Shared utilities including 80-column ANSI UI helpers, **Health 2.0** reporting, **blackboard schema validation**, **intelligent agent selection**, **agent analytics logging (P18.5)**, and **progress reporting (P18.3)**.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Includes **capability-based routing**, **multi-agent collaboration patterns (Review Pattern) (P18.2)**, **real-time tmux status bar updates (P17.4)**, and an **Autonomous Fleet Watchdog**.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring. Features a **Fleet Status** section with **real-time agent progress and task steps (P18.3)**.
- `scripts/dashboard-launch.sh`: Enhanced dashboard launcher (v3.0) with **adaptive tmux layouts (P17.1)**, **focus mode (P17.2)**, **real-time status bar (P17.4)**, and **session persistence (P17.5)**.
- `scripts/debug-mode.sh`: Debug mode wrapper that loads project context (product.md, tech-stack.md, KB) for focused LLM troubleshooting sessions with KB/RAG integration.
- `webui/app_refactored.py`: Modular Flask-based API server (v3.0) using blueprints for core services (terminal, system, config, kb, models).
- `webui/index.html`: Single-page application featuring **xterm.js web terminals**, **multi-project switcher**, real-time monitoring, and module configuration.
- `scripts/module-manager.py`: Logic for discovering, parsing, and loading module configurations with enable/disable support.
- `Dockerfile`: Containerizes the Orchestration Hub and Web UI with optimized dependencies.
- `docker-compose.yml`: Multi-service orchestration for the Hub, Web UI, and optional local LLM backends (vLLM).
- `docker/entrypoint.sh`: Container initialization with health checks and first-run detection.

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection. Supports `nemoclaw`, NVIDIA NIM, and local vLLM backends. Includes **real-time stdout parsing for progress tracking (P18.3)** and **performance analytics logging (P18.5)**.
- `scripts/nemoclaw-hcom.sh`: Specific spoke for the NVIDIA NIM nemoclaw architectural lead.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.
- `system-prompts/`: High-power role definitions for Gemini, Qwen, DeepSeek, and nemoclaw.

## Configuration & Schema
- `config/config.toml`: Centralized configuration with relay, launch, and terminal settings.
- `config/config.schema.json`: JSON schema for configuration validation.
- `config/blackboard-schema.json`: Schema definition for blackboard key namespaces, reserved namespaces, value constraints, and TTL policies.
- `config/agent-capabilities.json`: Capability scores (0.0-1.0) for 6 agents across 6 dimensions, with task keywords and capability weights for intelligent routing.

## Modular Addons
- `modules/atari-8bit/`: Specialized module for 6502 assembly and Atari hardware engineering.
  - `modules/atari-8bit/module.toml`: Manifest defining Atari-specific commands and dashboards.
  - `modules/atari-8bit/scripts/`: Performance profilers, memory map generators, and visual sync tools.
- `modules/nemoclaw/`: Spoke-specific addon for architectural review and status monitoring.

## CI/CD & Deployment
- `.github/workflows/ci-cd.yml`: 7-stage CI/CD pipeline: Lint → Unit Tests → Shell Tests → Web UI Tests → Docker Build → Integration Tests → Summary Report.
- `.github/workflows/webui-tests.yml`: GitHub Actions workflow for automated Web UI testing on push/PR.
- `scripts/cicd-build.sh`: Builds the self-hosted Hub container image.
- `scripts/cicd-deploy-runpod.sh`: Deploys specialized 'Spoke' compute environments to RunPod.
- `scripts/cicd-deploy-nvidia.sh`: Integration and verification for NVIDIA NIM/API hosted spokes.
- `scripts/webui-test-watcher.py`: Python file watcher for local automated testing during development.
- `scripts/webui-test-watch.sh`: Bash launcher for the file watcher with dependency management.

## Testing & Quality Assurance
- `tests/test_webui.sh`: Comprehensive Web UI test suite (8 automated tests).
- `tests/test_workspace_manager.py`: Unit tests for git repository discovery and registry management.
- `tests/test_portable_python.sh`: Verification of `uv` standalone Python isolation logic.
- `tests/test_python_env_optimization.sh`: Integration tests for the universal environment manager.
- `tests/test_dashboard_fixes.sh`: Dashboard launcher verification tests.
- `tests/test_config_manager.sh`: Automated test suite for the unified configuration foundation.
- `tests/test_install_wizard.sh`: Integration tests for the interactive installer and CLI experience.
- `tests/test_fleet_autonomy.sh`: Verification of Health 2.0 metrics and Blackboard reporting.
- `tests/test_fleet_recovery.sh`: End-to-end simulation of agent crash detection and Watchdog recovery.
- `tests/test_module_hooks.sh`: Verification of dynamic periodic hooks and manifest parsing.
- `tests/test_message_queue.sh`: **NEW (P16.1)** - Message queue layer tests (send, queue, retry, dead-letter, TTL).
- `tests/test_event_cursor.sh`: **NEW (P16.2)** - Event processing resilience tests (cursor persistence, deduplication, crash recovery).
- `tests/test_blackboard_schema.sh`: **NEW (P16.3)** - Blackboard schema validation tests (namespace validation, reserved protection, TTL, atomic ops).
- `tests/test_agent_selection.sh`: **NEW (P16.4)** - Intelligent agent selection tests (capability scores, task analysis, routing, fallback).
- `tests/test_agent_recovery.sh`: **NEW (P16.5)** - Agent recovery tests (exponential backoff, circuit breaker, rerouting).
- `tests/test_mqtt_broker.sh`: **NEW (P16.6)** - MQTT broker setup tests (config, TLS, auth, persistence, docs).
- `tests/test_dynamic_layouts.sh`: **NEW (P17.1)** - Dynamic tmux layout tests (selection, thresholds, descriptions, integration).
- `tests/test_focus_mode.sh`: **NEW (P17.2)** - Focus mode tests (focus/return functions, status bar, dashboard integration).
- `tests/test_enhanced_console.sh`: **NEW (P17.3)** - Enhanced console tests (readline, history, completion, help, conductor commands).
- `tests/test_status_bar.sh`: **NEW (P17.4)** - Fleet status bar tests (heartbeat data, tmux updates, 20s interval, agent states).
- `tests/test_session_persistence.sh`: **NEW (P17.5)** - Session persistence tests (save/restore scripts, JSON format, named presets, dashboard integration).
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
- Source: Milestone 21 & 22 Architectural Review
- Latest Enhancements: **Web UI v3.0**, **Console UX Revolution**, **Task Orchestration Intelligence**, **Quality Gates**
