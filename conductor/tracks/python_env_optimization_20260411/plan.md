# Implementation Plan: Python Environment Optimization

## Phase 1: Environment Manager Script
1.  **Develop `scripts/python-env-manager.sh`**:
    *   Implement detection logic for: `uv`, `conda`, `mamba`, `poetry`, `pixi`, `venv`, `pyenv`.
    *   Define a standardized activation function.
    *   Add support for creating a new environment using the detected manager.
    *   Ensure proper fallback to `uv` (offer installation if missing).

## Phase 2: Integration
1.  **Update `install.sh`**:
    *   Replace existing inline detection with calls to `scripts/python-env-manager.sh`.
    *   Ensure the environment is created/activated before installing `requirements.txt`.
2.  **Update `launch.sh`**:
    *   Use `scripts/python-env-manager.sh` to activate the correct environment.
    *   Support both local and WebUI environments.

## Phase 3: Validation & Testing
1.  **Develop `tests/test_python_env_optimization.sh`**:
    *   Mock different environment managers (e.g., faking `uv` or `conda` in the PATH).
    *   Verify that `scripts/python-env-manager.sh` correctly identifies the mock manager.
    *   Test environment creation and activation.
    *   Ensure no regressions in existing `install.sh` and `launch.sh` functionality.

## Timeline
- **Phase 1**: Initial script development and unit testing.
- **Phase 2**: Integration with core scripts.
- **Phase 3**: Comprehensive testing and final validation.
