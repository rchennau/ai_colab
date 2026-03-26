# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-03-25 (Dashboard v2.4 Fixes & Stability Update)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher for the Dashboard and Conductor. Refactored to use central `config-manager.sh`.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, and `--auto` modes.
- `scripts/install-wizard.sh`: Interactive terminal-based configuration wizard (5-step guided setup). Enhanced with 80-column ANSI UI.
- `scripts/migrate-project.sh`: Project Detection & Migration Tool. Automatically imports existing AI integrations.
- `scripts/utils.sh`: Shared utilities including new 80-column ANSI UI helpers (banners, boxes, status items).
- `scripts/config-manager.sh`: Unified configuration management with validation against `config/config.schema.json`. Supports get/set/validate/backup/restore operations.
- `config/config.schema.json`: Central source of truth for all project configurations and preferences.
- `config/profiles/`: Pre-defined configuration profiles (minimal, standard, full).
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Handles Git lifecycle, semantic KB search, and task spawning.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring.
- `scripts/dashboard-launch.sh`: Enhanced dashboard launcher (v2.4) with pre-flight checks, session recovery, health monitoring, and cross-version tmux compatibility (fixes -P flag incompatibility).
- `webui/app.py`: Flask-based API and web server (v2.0) with enhanced health checks, session management, and agent monitoring.
- `webui/index.html`: Single-page application for the Web UI, featuring setup wizards, real-time monitoring, and pre-flight checks.
- `scripts/module-manager.py`: Logic for discovering and registering manifest-based modular addons.
- `Dockerfile`: Containerizes the Orchestration Hub and Web UI with optimized dependencies.
- `docker-compose.yml`: Multi-service orchestration for the Hub, Web UI, and optional local LLM backends (vLLM).
- `docker/entrypoint.sh`: Container initialization with health checks and first-run detection.

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection. Now supports `nemoclaw` and NVIDIA NIM backends.
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
- `scripts/cicd-deploy-nvidia.sh`: Integration and verification for NVIDIA NIM/API hosted spokes (now includes `nemoclaw` verification).
- `.github/workflows/webui-tests.yml`: GitHub Actions workflow for automated Web UI testing on push/PR.
- `scripts/webui-test-watcher.py`: Python file watcher for local automated testing during development.
- `scripts/webui-test-watch.sh`: Bash launcher for the file watcher with dependency management.

## Testing & Quality Assurance
- `tests/test_webui.sh`: Comprehensive Web UI test suite (8 automated tests).
  - Health endpoint verification
  - Pre-flight checks API
  - Session status monitoring
  - Agent list from hcom
  - Configuration management
  - System status endpoint
  - Dashboard launch endpoint
  - Frontend HTML verification
- `tests/test_dashboard_fixes.sh`: Dashboard launcher verification tests (11 automated tests covering tmux syntax, flag propagation, and hcom initialization).
- `tests/test_config_manager.sh`: Automated test suite for the unified configuration foundation.
- `tests/test_install_wizard.sh`: Integration tests for the interactive installer and CLI experience.
- `tests/webui-test-config.ini`: Configuration file for automated testing system.

## Documentation
- `docs/INSTALLATION.md`: Comprehensive installation guide covering CLI wizard, Web UI, and Docker pathways.
- `docs/WEBUI_GUIDE.md`: Complete Web UI user guide with API reference.
- `docs/AUTOMATED_WEBUI_TESTING.md`: Guide for automated testing setup and usage.
- `conductor/tracks/enhanced_install_launch_20260324/`: Milestone 11 implementation track.
  - `dashboard-improvements-v2.4.md`: CLI dashboard enhancement documentation.
  - `webui-improvements-v2.0.md`: Web UI enhancement documentation.
  - `webui-test-results.md`: Web UI test results and verification.
  - `webui-automation-summary.md`: Automated testing implementation summary.
  - `dashboard-fixes.md`: Original dashboard bug fixes documentation.

## Index Metadata
- Status: Active
- Source: Milestone 11, 12 & 13 Architectural Review
- Architecture: Hub and Spoke (Self-Hosted Hub)
- Latest Enhancements: Web UI v2.0, Dashboard v2.4, Automated Testing CI/CD
