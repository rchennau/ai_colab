# Plan: Generic Module Plugin System

## Phase 1: Foundation & Manifest
- [ ] Task: Create `modules/atari-lx/module.toml` based on the new specification.
- [ ] Task: Develop a helper script `scripts/module-manager.sh` to parse TOML manifests (using `sed/awk` or a small Python helper for robustness).

## Phase 2: Orchestration Integration
- [ ] Task: Update `launch.sh` to use the manifest for environment variables and flags.
- [ ] Task: Update `scripts/conductor-workflow.sh` to dynamically load command hooks from active modules.
  - Remove hardcoded `!screenshot`, `!memory-map`, etc.
- [ ] Task: Update `scripts/conductor-dashboard.sh` to render modular UI sections.

## Phase 3: Setup Automation
- [ ] Task: Update `install.sh` to dynamically discover modules and handle their specific dependencies.
- [ ] Task: Update `scripts/conductor/install.sh` to ensure modular scripts are correctly linked in the global environment.

## Phase 4: Verification & Testing
- [ ] Task: Create a "Mock Module" and verify it can be enabled/disabled without side effects.
- [ ] Task: Verify that `!help` updates correctly when modules are toggled.
