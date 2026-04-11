#!/usr/bin/env bash
# ai-colab Python Environment Manager
# Detects, creates, and activates Python environments using various managers

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Detect Python environment manager
detect_manager() {
    # Check if already in a virtual environment
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        echo "venv_active"
        return
    fi

    if [[ -n "${CONDA_DEFAULT_ENV:-}" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        echo "conda_active"
        return
    fi

    # Preference order: uv > pixi > mamba > conda > poetry > venv > pyenv
    if has_command uv; then
        echo "uv"
    elif has_command pixi; then
        echo "pixi"
    elif has_command mamba; then
        echo "mamba"
    elif has_command conda; then
        echo "conda"
    elif has_command poetry; then
        echo "poetry"
    elif python3 -m venv --help >/dev/null 2>&1; then
        echo "venv"
    elif has_command pyenv; then
        echo "pyenv"
    else
        echo "none"
    fi
}

# Create a new environment using the detected manager
create_env() {
    local manager="$1"
    local env_name="${2:-ai-colab}"
    local venv_path="$PROJECT_ROOT/.venv"

    case "$manager" in
        uv)
            echo -e "${BLUE}Creating environment with uv...${NC}"
            uv venv "$venv_path"
            ;;
        pixi)
            echo -e "${BLUE}Creating environment with pixi...${NC}"
            pixi init "$PROJECT_ROOT" --non-interactive
            ;;
        mamba|conda)
            echo -e "${BLUE}Creating environment with $manager: $env_name...${NC}"
            $manager create -n "$env_name" python=3.11 -y
            ;;
        poetry)
            echo -e "${BLUE}Creating environment with poetry...${NC}"
            poetry install
            ;;
        venv)
            echo -e "${BLUE}Creating environment with venv...${NC}"
            python3 -m venv "$venv_path"
            ;;
        none)
            echo -e "${YELLOW}No environment manager found. Defaulting to uv...${NC}"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo -e "${BLUE}Installing uv via brew...${NC}"
                brew install uv || (curl -LsSf https://astral.sh/uv/install.sh | sh)
            else
                echo -e "${BLUE}Installing uv via curl...${NC}"
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            # Re-detect after install
            if has_command uv; then
                uv venv "$venv_path"
            else
                echo -e "${RED}Failed to install uv. Falling back to system python (not recommended).${NC}"
            fi
            ;;
    esac
}

# Get activation command for the detected manager
get_activate_cmd() {
    local manager="$1"
    local env_name="${2:-ai-colab}"
    local venv_path="$PROJECT_ROOT/.venv"

    case "$manager" in
        uv|venv|venv_active)
            echo "source \"$venv_path/bin/activate\""
            ;;
        conda|conda_active|mamba)
            echo "conda activate \"$env_name\""
            ;;
        pixi)
            echo "pixi shell"
            ;;
        poetry)
            echo "poetry shell"
            ;;
        *)
            echo "true" # No-op
            ;;
    esac
}

# Main entry point
main() {
    local cmd="${1:-detect}"
    shift || true

    case "$cmd" in
        detect)
            detect_manager
            ;;
        create)
            local manager=$(detect_manager)
            create_env "$manager" "$@"
            ;;
        activate-cmd)
            local manager=$(detect_manager)
            get_activate_cmd "$manager" "$@"
            ;;
        *)
            echo "Usage: $0 {detect|create|activate-cmd}"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
