# ai-colab Project Map (Semantic Knowledge Base)
Generated: 2026-03-24 10:55:00 (Manual Update)

## Orchestration Core (Hub)
- `launch.sh`: Unified launcher for the Dashboard and Conductor. Supports compute backend selection.
- `install.sh`: Master installer for project dependencies and modular addons.
- `scripts/conductor-workflow.sh`: The heart of the orchestration logic. Handles Git lifecycle, semantic KB search, and task spawning.
- `scripts/conductor-dashboard.sh`: High-density TUI for real-time project monitoring.
- `scripts/hcom-web-dashboard.py`: Flask-based web UI for performance and event analytics.
- `scripts/module-manager.py`: Logic for discovering and registering manifest-based modular addons.
- `Dockerfile`: Containerizes the Orchestration Hub (control plane only).

## AI Agent Integration (Spokes)
- `scripts/agent-wrapper.sh`: Unified core for registering agents with `hcom`, maintaining heartbeats, and role injection.
- `scripts/hcom-kb-index.sh`: LLM-powered indexer for semantic project-wide knowledge.
- `mcp/core-dev/server.py`: MCP server providing specialized development tools to LLM agents.

## Modular Addons
- `modules/atari-lx/`: Specialized module for 6502 assembly and Atari hardware engineering.
  - `modules/atari-lx/module.toml`: Manifest defining Atari-specific commands and dashboards.
  - `modules/atari-lx/scripts/`: Performance profilers, memory map generators, and visual sync tools.

## CI/CD & Deployment
- `scripts/cicd-build.sh`: Builds the self-hosted Hub container image.
- `scripts/cicd-deploy-runpod.sh`: Deploys specialized 'Spoke' compute environments to RunPod.
- `scripts/cicd-deploy-nvidia.sh`: Integration for NVIDIA NIM/API hosted spokes.

## Index Metadata
- Status: Active
- Source: Manual Architectural Refinement
- Architecture: Hub and Spoke (Self-Hosted Hub)
