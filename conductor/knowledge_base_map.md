# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-04-10 (Phase 16: Foundation Hardening Complete)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher with **three launch modes** (Dashboard, WebUI, Debug) and **module enablement** (`-m/--module` flag). Auto-activates `.venv` virtual environment. Supports **multi-project discovery** and global CLI model. **Pre-launch summary** with comprehensive configuration display and "press any key" confirmation.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, `--auto`, and **`--global`** modes. **Auto-detects Python environment** (uv → conda → venv → system) and creates virtual environment in `.venv/`.
- `.venv/`: **Auto-created** virtual environment for Python dependencies. Activated by all project scripts.
- `scripts/python-env-manager.sh`: **NEW** - Universal Python environment manager. Detects uv, conda, venv, pixi, and pyenv. Supports **standalone portable Python distributions** via `uv python install`.
- `scripts/workspace_manager.py`: **NEW** - Logic for scanning directories for Git repositories and managing the global `workspace.json` registry.
- `scripts/message-queue.sh`: **NEW (P16.1)** - SQLite-based message queue layer providing **reliable message delivery**, offline queuing, exponential backoff retry, dead-letter queue, and TTL enforcement.
- `scripts/utils.sh`: Shared utilities including 80-column ANSI UI helpers, **Health 2.0** reporting, **blackboard schema validation (P16.3)**, **intelligent agent selection (P16.4)**, **circuit breaker (P16.5)**, and **event cursor (P16.2)**.
- `scripts/config-manager.sh`: Unified configuration management with validation against `config/config.schema.json`.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Includes **capability-based agent selection (P16.4)**, **circuit breaker awareness (P16.5)**, **persistent event cursor (P16.2)**, and an **Autonomous Fleet Watchdog** for stale agent detection.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring. Features a **Fleet Health** section for spoke monitoring.
- `scripts/dashboard-launch.sh`: Enhanced dashboard launcher (v2.4) with **improved pane layout (right column first)**, **proper timing delays**, **wrapper scripts for agent launch**, and **8-line console**.
- `scripts/debug-mode.sh`: Debug mode wrapper that loads project context (product.md, tech-stack.md, KB) for focused LLM troubleshooting sessions with KB/RAG integration.
- `scripts/test-all.sh`: **NEW** - Unified test harness supporting `--ci`, `--verbose`, `--skip-*` flags with JSON summary output.
- `scripts/install-wizard.sh`: Interactive terminal-based configuration wizard (5-step guided setup). Enhanced with 80-column ANSI UI.
- `scripts/migrate-project.sh`: Project Detection & Migration Tool. Automatically imports existing AI integrations.
- `scripts/module-manager.sh`: Module management with enable/disable commands for WebUI and CLI integration.
- `webui/app_refactored.py`: **NEW** - Modular Flask-based API server (v3.0) using blueprints for core services (terminal, system, config, kb, models).
- `webui/index.html`: Single-page application featuring **xterm.js web terminals**, setup wizards, real-time monitoring, tabbed terminal interface, module configuration, and **multi-project switcher**.
- `scripts/module-manager.py`: Logic for discovering, parsing, and loading module configurations with enable/disable support.
- `Dockerfile`: Containerizes the Orchestration Hub and Web UI with optimized dependencies.
- `docker-compose.yml`: Multi-service orchestration for the Hub, Web UI, and optional local LLM backends (vLLM). **Pending: MQTT service (P16.6)**.
- `docker/entrypoint.sh`: Container initialization with health checks and first-run detection.

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection. Supports `nemoclaw`, NVIDIA NIM, and local vLLM backends. Includes **exponential backoff restart (P16.5)** and **circuit breaker integration (P16.5)**.
- `scripts/nemoclaw-hcom.sh`: Specific spoke for the NVIDIA NIM nemoclaw architectural lead.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.
- `system-prompts/`: High-power role definitions for Gemini, Qwen, DeepSeek, and nemoclaw.

## Configuration & Schema
- `config/config.toml`: Centralized configuration with relay, launch, and terminal settings.
- `config/config.schema.json`: JSON schema for configuration validation.
- `config/blackboard-schema.json`: **NEW (P16.3)** - Schema definition for blackboard key namespaces, reserved namespaces, value constraints, and TTL policies.
- `config/agent-capabilities.json`: **NEW (P16.4)** - Capability scores (0.0-1.0) for 6 agents across 6 dimensions, with task keywords and capability weights for intelligent routing.

## Modular Addons
- `modules/atari-8bit/`: Specialized module for 6502 assembly and Atari hardware engineering.
  - `modules/atari-8bit/module.toml`: Manifest defining Atari-specific commands and dashboards.
  - `modules/atari-8bit/scripts/`: Performance profilers, memory map generators, and visual sync tools.
- `modules/nemoclaw/`: Spoke-specific addon for architectural review and status monitoring.

## CI/CD & Deployment
- `.github/workflows/ci-cd.yml`: **NEW** - 7-stage CI/CD pipeline: Lint → Unit Tests → Shell Tests → Web UI Tests → Docker Build → Integration Tests → Summary Report.
- `.github/workflows/webui-tests.yml`: GitHub Actions workflow for automated Web UI testing on push/PR.
- `scripts/cicd-build.sh`: Builds the self-hosted Hub container image.
- `scripts/cicd-deploy-runpod.sh`: Deploys specialized 'Spoke' compute environments to RunPod.
- `scripts/cicd-deploy-nvidia.sh`: Integration and verification for NVIDIA NIM/API hosted spokes.
- `scripts/webui-test-watcher.py`: Python file watcher for local automated testing during development.
- `scripts/webui-test-watch.sh`: Bash launcher for the file watcher with dependency management.

## Testing & Quality Assurance
- `conductor/qa-framework.md`: **NEW** - Comprehensive QA framework with test pyramid, quality gates, defect management, security testing, and performance benchmarks.
- `scripts/test-all.sh`: **NEW** - Unified test harness for running all test suites with configurable filtering.
- `tests/test_message_queue.sh`: **NEW (P16.1)** - 18 tests for message queue layer (send, queue, retry, dead-letter, TTL).
- `tests/test_event_cursor.sh`: **NEW (P16.2)** - 16 tests for event processing resilience (cursor persistence, deduplication, crash recovery).
- `tests/test_blackboard_schema.sh`: **NEW (P16.3)** - 25 tests for schema validation (namespace validation, reserved protection, TTL, atomic ops).
- `tests/test_agent_selection.sh`: **NEW (P16.4)** - 47 tests for intelligent agent selection (capability scores, task analysis, routing, fallback).
- `tests/test_agent_recovery.sh`: **NEW (P16.5)** - 23 tests for agent recovery (exponential backoff, circuit breaker, rerouting).
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
