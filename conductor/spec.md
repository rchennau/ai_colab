# Track Specification: The Plugin Economy (Phase 21)

## Overview
This track focuses on transforming the existing module system into a thriving "Plugin Economy." Currently, modules are manually copied into the `modules/` directory. This track will introduce a centralized registry, a dedicated CLI tool for discovery and installation (`ai-colab module install <name>`), and strict sandboxing for third-party plugins.

## Goals
1.  **Standardize Manifests**: Formalize the `module.toml` schema to support dependencies, permissions, and versioning.
2.  **Module Registry**: Create a centralized index (e.g., a GitHub repo acting as a registry) where community developers can publish their plugins.
3.  **CLI Integration**: Implement `ai-colab module search`, `install`, `update`, and `remove` commands.
4.  **Sandboxed Execution**: Ensure that third-party plugins execute in isolated environments (e.g., using the portable Python `uv` environments or Docker containers) to prevent unauthorized system access or conflicts.

## Requirements
- **Registry Schema**: Define the JSON/TOML format for the central registry.
- **CLI Commands**: Extend `scripts/module-manager.py` or create `scripts/module-marketplace.sh` to handle remote fetching and dependency resolution.
- **Security**: Implement a permission model in `module.toml` (e.g., `requires_network`, `requires_file_write`) that the user must explicitly approve upon installation.

## Success Criteria
- [ ] Users can run `ai-colab module search` to find available plugins.
- [ ] Users can install a remote plugin via `ai-colab module install <plugin-name>`.
- [ ] The system prompts for security permissions before activating a new plugin.
- [ ] Plugins execute in an isolated `uv` virtual environment or Docker container.
