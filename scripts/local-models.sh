#!/usr/bin/env bash
# ai-colab Local Models (P5.1)
# Shell wrapper for the model manager
# Usage: bash local-models.sh <command> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL_MANAGER="$SCRIPT_DIR/model-manager.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# Show help
show_help() {
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo "  bash local-models.sh <command> [options]"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  list          List available local models"
    echo "  download      Download a model"
    echo "  status        Show overall model status"
    echo "  health        Check runtime health"
    echo "  recommend     Recommend model for task"
    echo "  help          Show this help message"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --model <id>      Model ID for download/recommend"
    echo "  --task <type>     Task type for recommendation"
    echo "  --runtime <name>  Filter by runtime (ollama/llamacpp/vllm_local)"
    echo ""
    echo -e "${BLUE}Supported Runtimes:${NC}"
    echo "  ollama      - Ollama (recommended for most users)"
    echo "  llamacpp    - llama.cpp (GGUF models)"
    echo "  vllm_local  - Local vLLM deployment"
    echo ""
    echo -e "${BLUE}Example Models:${NC}"
    echo "  qwen2.5-coder-7b   - 7B coding model (4.7GB, 8GB RAM)"
    echo "  llama3.1-8b        - 8B general model (4.9GB, 8GB RAM)"
    echo "  phi3-mini          - Lightweight model (2.3GB, 4GB RAM)"
}

# ============================================================
# Main
# ============================================================

main() {
    local command=""
    local model=""
    local task=""
    local runtime=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            list|download|status|health|recommend|help)
                command="$1"
                shift
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --task)
                task="$2"
                shift 2
                ;;
            --runtime)
                runtime="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Handle help command
    if [[ "$command" == "help" || -z "$command" ]]; then
        show_help
        exit 0
    fi

    # Build command
    local cmd=(python3 "$MODEL_MANAGER" "$command")
    [[ -n "$model" ]] && cmd+=(--model "$model")
    [[ -n "$task" ]] && cmd+=(--task "$task")
    [[ -n "$runtime" ]] && cmd+=(--runtime "$runtime")

    # Execute
    "${cmd[@]}"
}

main "$@"
