# Track Specification: Python Environment Optimization

## Overview
This track aims to optimize the Python environment management for ai-colab. The system will intelligently detect existing Python environment managers (uv, conda, mamba, poetry, pixi, pyenv) and leverage them to create a project-specific environment. If no such manager is found, the system will default to using `uv` for high-performance environment management.

## Goals
- **Intelligent Detection**: Detect and support multiple Python environment managers.
- **UV Default**: Use `uv` as the default high-performance fallback.
- **Environment Consistency**: Ensure both `install.sh` and `launch.sh` use the same environment.
- **User Preference**: Respect existing environments if activated.
- **Atomic Creation**: Ensure environments are created cleanly and can be re-created.

## Requirements
1.  **Detection Script**: A dedicated script (`scripts/python-env-manager.sh`) to detect and activate environments.
2.  **Manager Support**: Support for `uv`, `conda`, `mamba`, `poetry`, `pixi`, `venv`, and `pyenv`.
3.  **Install Integration**: `install.sh` should call the manager to create/activate the environment before installing dependencies.
4.  **Launch Integration**: `launch.sh` should call the manager to activate the correct environment.
5.  **Test Harness**: A test script to verify detection and activation across different simulated environments.

## Success Criteria
- [ ] `scripts/python-env-manager.sh` accurately detects at least 3 different managers.
- [ ] `install.sh` successfully creates an environment using the detected manager.
- [ ] `launch.sh` activates the same environment.
- [ ] If no manager is present, the system offers to install or use `uv`.
- [ ] Automated tests pass across simulated scenarios.
