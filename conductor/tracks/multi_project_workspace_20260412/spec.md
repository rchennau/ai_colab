# Track Specification: Multi-Project Workspace & Portable Environment

## Overview
This track evolves `ai_colab` from a localized script into a globally installed, portable CLI and orchestration hub. It introduces multi-project workspace switching and true OS independence by leveraging `uv` for downloading standalone Python distributions.

## Goals
1.  **Global CLI Model**: Install `ai_colab` globally (e.g., `~/.ai-colab`) and provide an `ai-colab` command in the user's PATH.
2.  **Git Repository Discovery**: Scanning the current or target directory for `.git` repositories and prompting the user to manage them.
3.  **Project Organization & Switching**: A global registry (`workspace.toml`) to track managed projects, with the ability to switch contexts in the CLI and WebUI.
4.  **Self-Management**: `ai_colab` itself will be registered as a managed project.
5.  **True Portability**: Ensure zero reliance on the host OS Python by using `uv python install 3.11` to fetch isolated Python distributions.

## Requirements
- **Installation**: Update `install.sh` to support global installation and `PATH` modification.
- **Environment**: Update `scripts/python-env-manager.sh` to enforce portable Python via `uv`.
- **Discovery**: A new `scripts/workspace-manager.py` to scan directories (max depth 2) for `.git` and manage `workspace.toml`.
- **Launcher**: `launch.sh` (wrapped as `ai-colab`) must distinguish between `AI_COLAB_HOME` (installation) and `WORKSPACE_ROOT` (target project).
- **WebUI**: A project switcher dropdown in the WebUI to seamlessly restart agents in a new context.

## Success Criteria
- [ ] `install.sh` creates a globally available `ai-colab` command.
- [ ] Portable Python 3.11 is downloaded via `uv` without using system Python.
- [ ] Running `ai-colab` in a directory scans for git repos and prompts for registration.
- [ ] `ai_colab` is self-registered as a project.
- [ ] WebUI allows switching between managed projects.
- [ ] Comprehensive QA harness validates Unit, Feature, System, and E2E flows.
