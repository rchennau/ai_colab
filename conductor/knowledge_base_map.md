# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-04-11 (Phase 20: Strategic Moats Complete ✅ — 296 tests passing across 4 phases)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher with **three launch modes** (Dashboard, WebUI, Debug) and **module enablement** (`-m/--module` flag). Auto-activates virtual environment. Supports **multi-project discovery** and global CLI model.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, `--auto`, and **`--global`** modes. **Auto-detects Python environment** (uv → conda → venv → system) and creates virtual environment in `.venv/`.
- `scripts/console.py`: Enhanced Python-based interactive command console with history, tab-completion, and multi-line support.
- `scripts/quality-gates.sh`: Automated code quality validation framework (Linting, Security, Syntax) integrated into the merge workflow.
- `scripts/local-models.sh`: **NEW (P5.1)** - Local LLM model management shell wrapper.
- `scripts/model-manager.py`: **NEW (P5.1)** - Local model registry, download, and recommendation engine with 8 pre-configured models.
- `scripts/agent-benchmark.sh`: **NEW (P19.5)** - Standardized agent evaluation framework. Compares LLM performance across coding, reasoning, and architecture tasks.
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
- `docker/agents/`: **NEW (P19.1)** - Collection of specialized agent images (Gemini, Claude, Qwen, DeepSeek) for reproducible distributed execution.
- `scripts/build-agent-images.sh`: **NEW (P19.1)** - Unified build system for the agent Docker fleet.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.
- `system-prompts/`: High-power role definitions for Gemini, Qwen, DeepSeek, and nemoclaw.

## Testing & Quality Assurance

### Phase 16: Foundation Hardening (148 tests)
- `tests/test_message_queue.sh`: **NEW (P16.1)** - Message queue layer tests (send, queue, retry, dead-letter, TTL).
- `tests/test_event_cursor.sh`: **NEW (P16.2)** - Event processing resilience tests (cursor persistence, deduplication, crash recovery).
- `tests/test_blackboard_schema.sh`: **NEW (P16.3)** - Blackboard schema validation tests (namespace validation, reserved protection, TTL, atomic ops).
- `tests/test_agent_selection.sh`: **NEW (P16.4)** - Intelligent agent selection tests (capability scores, task analysis, routing, fallback).
- `tests/test_agent_recovery.sh`: **NEW (P16.5)** - Agent recovery tests (exponential backoff, circuit breaker, rerouting).
- `tests/test_mqtt_broker.sh`: **NEW (P16.6)** - MQTT broker setup tests (config, TLS, auth, persistence, docs).

### Phase 17: Console UX Revolution (50 tests)
- `tests/test_dynamic_layouts.sh`: **NEW (P17.1)** - Dynamic tmux layout tests (selection, thresholds, descriptions, integration).
- `tests/test_focus_mode.sh`: **NEW (P17.2)** - Focus mode tests (focus/return functions, status bar, dashboard integration).
- `tests/test_enhanced_console.sh`: **NEW (P17.3)** - Enhanced console tests (readline, history, completion, help, conductor commands).
- `tests/test_status_bar.sh`: **NEW (P17.4)** - Fleet status bar tests (heartbeat data, tmux updates, 20s interval, agent states).
- `tests/test_session_persistence.sh`: **NEW (P17.5)** - Session persistence tests (save/restore scripts, JSON format, named presets, dashboard integration).

### Phase 19: Ecosystem Expansion (30 tests)
- `tests/test_docker_deployment.sh`: **NEW (P19.2)** - Docker deployment tests (compose syntax, services, volumes, networks, health checks).
- `tests/test_agent_benchmark.sh`: **NEW (P19.5)** - Agent benchmarking tests (task suite, runner, report generator).
- `tests/test_container_agents.sh`: Verification harness for the containerized agent isolation system.

### Phase 20: Strategic Moats (68 tests)
- `tests/test_local_models.sh`: **NEW (P5.1)** - Local LLM support tests (28 tests across 6 categories: file structure, config validation, commands, shell wrapper, edge cases, integration).
- `tests/test_agent_memory.sh`: **NEW (P5.2)** - Agent memory tests (save/load operations, multiple messages, status, clear, context window limits).
- `tests/test_cost_tracker.sh`: **NEW (P5.3)** - Cost optimization tests (record/query usage, cost estimation, budget setting, alerts, ranking).
- `tests/test_conductor_failover.sh`: **NEW (P5.5)** - Conductor failover tests (health monitoring, restart logic, agent promotion, state recovery).

### Core Tests
- `tests/test_webui.sh`: Comprehensive Web UI test suite (8 automated tests).
- `tests/test_workspace_manager.py`: Unit tests for git repository discovery and registry management.
- `tests/test_portable_python.sh`: Verification of `uv` standalone Python isolation logic.
- `tests/test_python_env_optimization.sh`: Integration tests for the universal environment manager.
- `tests/test_dashboard_fixes.sh`: Dashboard launcher verification tests.
- `tests/test_config_manager.sh`: Automated test suite for the unified configuration foundation.
- `tests/test_fleet_autonomy.sh`: Verification of Health 2.0 metrics and Blackboard reporting.
- `tests/test_fleet_recovery.sh`: End-to-end simulation of agent crash detection and Watchdog recovery.
- `tests/test_api_key_detection.sh`: API key detection and web authentication tests.

## Configuration
- `config/config.toml`: Centralized configuration for terminal, launch, relay, and preferences.
- `config/blackboard-schema.json`: **NEW (P16.3)** - Blackboard key namespace schema with reserved namespaces and TTL policies.
- `config/agent-capabilities.json`: **NEW (P16.4)** - Agent capability scores (0.0-1.0) for 6 agents across 6 dimensions.
- `config/benchmark-tasks.json`: **NEW (P19.5)** - Standardized benchmark tasks for agent evaluation.
- `config/pricing.json`: **NEW (P5.3)** - LLM provider pricing tables (input/output per 1M tokens).
- `config/budget-config.json`: **NEW (P5.3)** - Budget limits and alert thresholds per agent.
- `config/memory-config.json`: **NEW (P5.2)** - Agent memory configuration (max messages, bytes, compression).
- `config/local-models.json`: **NEW (P5.1)** - Local model registry with 8 models across 3 runtimes.

## Documentation
- `docs/INSTALLATION.md`: Comprehensive installation guide.
- `PYTHON_ENV_SETUP.md`: Python environment setup guide with troubleshooting tips.
- `docs/WEBUI_GUIDE.md`: Complete Web UI user guide with API reference.
- `docs/AUTOMATED_WEBUI_TESTING.md`: Guide for automated testing setup and usage.
- `conductor/tracks/ecosystem_expansion_20260414/`: Milestone 23 implementation track.

## Index Metadata
- Status: Active
- Source: Milestone 21, 22 & 23 Architectural Review
- Latest Enhancements: **Web UI v3.0**, **Console UX Revolution**, **Task Orchestration Intelligence**, **Quality Gates**, **Containerized Agents**, **Agent Benchmarking**
