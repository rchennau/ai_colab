# Python Environment Setup

This document describes the Python environment management system implemented in the installation scripts.

## Overview

The installation scripts now automatically detect and configure the best available Python package management tool, with a preference order of:

1. **uv** (preferred) - Fast Python package installer
2. **conda** - Anaconda/Miniconda environment manager
3. **venv** - Standard Python virtual environment tool
4. **system pip** - Fallback with `--break-system-packages` flag (PEP 668)

## What Changed

### `install.sh`
- Added `detect_python_env()` function to automatically detect available Python environment managers
- Created `setup_venv_with_uv()` and `setup_venv_with_venv()` functions for environment creation
- Updated all Python package installations to use the detected package manager
- All pip commands now use `$PIP_CMD` variable instead of hardcoded `python3 -m pip`
- All Python commands now use `$PYTHON_CMD` variable instead of hardcoded `python3`
- Fixed requirements file paths to use `$PROJECT_ROOT` instead of `$SCRIPT_DIR`

### `launch.sh`
- Added automatic virtual environment activation if `.venv` exists
- Updated all Python and pip commands to use `$PYTHON_CMD` and `$PIP_CMD` variables
- Fixed dependency checks to use the correct Python environment
- Improved X11 display handling for pyautogui (graceful degradation in headless environments)

### `.gitignore`
- Added `.venv/` and `venv/` to ignore virtual environment directories

## How It Works

### Installation Flow

1. **Detection**: Script checks for available Python environment managers in order: uv → conda → venv → system
2. **Setup**: Creates/activates virtual environment in `$PROJECT_ROOT/.venv`
3. **Installation**: Installs all requirements using the appropriate package manager
4. **Verification**: Checks that critical dependencies are importable

### Environment Variables

- `PYTHON_CMD` - Python executable to use (respects virtual environment)
- `PIP_CMD` - Pip command to use (uses `uv pip` when uv is detected)
- `VIRTUAL_ENV` - Automatically set when virtual environment is activated

## For Developers

### Manual Environment Activation

If you need to work with the Python environment manually:

```bash
cd /path/to/ai_colab
source .venv/bin/activate
```

### Adding New Dependencies

Add your requirements to the appropriate `requirements-*.txt` file:
- `requirements-mcp.txt` - MCP Server dependencies
- `requirements-rag.txt` - RAG System dependencies
- `requirements-webui.txt` - Web UI dependencies
- `requirements-test.txt` - Test dependencies

The installer will automatically detect and install missing packages.

### Troubleshooting

**Issue**: "externally-managed-environment" error
**Solution**: The installer should now automatically create a virtual environment. If this fails, manually create one:
```bash
cd /path/to/ai_colab
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-*.txt
```

**Issue**: uv not found
**Solution**: Install uv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Issue**: Dependencies not importing correctly
**Solution**: Ensure virtual environment is activated:
```bash
source .venv/bin/activate
which python  # Should point to .venv/bin/python
```
