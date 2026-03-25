# ai-colab Project Map (Semantic Knowledge Base)
Last Updated: 2026-03-24 (Enhanced Installation & Launch Update)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher for the Dashboard and Conductor. Refactored to use central `config-manager.sh`.
- `install.sh`: Master installer for project dependencies. Supports `--wizard`, `--reconfigure`, and `--guide` modes.
- `scripts/install-wizard.sh`: Interactive terminal-based configuration wizard for initial setup and reconfiguration.
- `scripts/config-manager.sh`: Unified configuration management with validation against `config/config.schema.json`.
- `config/config.schema.json`: Central source of truth for all project configurations and preferences.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Handles Git lifecycle, semantic KB search, and task spawning.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring.
- `webui/app.py`: Flask-based API and web server for the browser-based configuration dashboard.
- `webui/index.html`: Single-page application for the Web UI, featuring setup wizards and real-time monitoring.
- `scripts/module-manager.py`: Logic for discovering and registering manifest-based modular addons.
- `Dockerfile`: Containerizes the Orchestration Hub and Web UI with optimized dependencies.
- `docker-compose.yml`: Multi-service orchestration for the Hub, Web UI, and optional local LLM backends (vLLM).

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection. Now supports `nemoclaw` and NVIDIA NIM backends.
- `scripts/nemoclaw-hcom.sh`: Specific spoke for the NeMo-Claude (nemoclaw) architectural lead.
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
- `tests/test_config_manager.sh`: Automated test suite for the unified configuration foundation.
- `tests/test_install_wizard.sh`: Integration tests for the interactive installer and CLI experience.

## Index Metadata
- Status: Active
- Source: Milestone 11 & 12 Architectural Review
- Architecture: Hub and Spoke (Self-Hosted Hub)
