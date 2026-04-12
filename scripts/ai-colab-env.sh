#!/usr/bin/env bash
# ai-colab Environment Setup
# Creates a clean, self-contained environment for ai-colab processes.
# Sources this script to ensure consistent behavior regardless of user's environment.
#
# Usage:
#   source scripts/ai-colab-env.sh    # In current shell
#   bash scripts/ai-colab-env.sh      # As wrapper command

# ============================================================
# Find Project Root
# ============================================================
if [[ -z "${AI_COLAB_PROJECT_ROOT:-}" ]]; then
    # Try to detect project root from SCRIPT_DIR or current directory
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        AI_COLAB_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    elif [[ -f "launch.sh" ]]; then
        AI_COLAB_PROJECT_ROOT="$(pwd)"
    else
        # Search up to 3 levels
        local dir="$(pwd)"
        for i in 1 2 3; do
            if [[ -f "$dir/launch.sh" ]]; then
                AI_COLAB_PROJECT_ROOT="$dir"
                break
            fi
            dir="$(dirname "$dir")"
        done
    fi
fi

if [[ -z "${AI_COLAB_PROJECT_ROOT:-}" ]]; then
    echo "Error: Could not find ai-colab project root" >&2
    return 1 2>/dev/null || exit 1
fi

export AI_COLAB_PROJECT_ROOT

# ============================================================
# Minimal Environment Variables
# ============================================================

# PATH - Ensure essential paths are available
# Keep existing PATH but add ai-colab scripts directory
case ":$PATH:" in
    *:"$AI_COLAB_PROJECT_ROOT/scripts":*) ;;
    *) export PATH="$AI_COLAB_PROJECT_ROOT/scripts:$PATH" ;;
esac

# Standard paths
export HOME="${HOME:-$(eval echo ~${USER:-})}"
export USER="${USER:-$(whoami)}"
export SHELL="${SHELL:-/bin/bash}"
export TERM="${TERM:-xterm-256color}"

# Language settings
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Editor and pager defaults (don't rely on user's preferences)
export EDITOR="${EDITOR:-vi}"
export PAGER="${PAGER:-less}"

# Python environment
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1

# ai-colab specific variables
export AI_COLAB_ENV_LOADED=true

# ============================================================
# Clean Up User Environment
# ============================================================

# Remove potentially interfering aliases
unalias -a 2>/dev/null || true

# Remove shell functions that might interfere
# (Keep only bash builtins and ai-colab functions)
# Note: We can't easily remove all functions, but we set strict mode

# Set strict mode for predictable behavior
set -euo pipefail

# Disable history expansion (! in interactive shells)
set +H 2>/dev/null || true

# ============================================================
# Source ai-colab utilities
# ============================================================

# Source utils.sh for blackboard, hcom, and other functions
if [[ -f "$AI_COLAB_PROJECT_ROOT/scripts/utils.sh" ]]; then
    source "$AI_COLAB_PROJECT_ROOT/scripts/utils.sh" >/dev/null 2>&1 || true
fi

# ============================================================
# Working Directory
# ============================================================

# Ensure we're in the project root
cd "$AI_COLAB_PROJECT_ROOT" 2>/dev/null || true
