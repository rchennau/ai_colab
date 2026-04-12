#!/usr/bin/env bash
# ai-colab Agent Benchmark Runner (P4.5)
# Shell wrapper for the Python benchmark runner
# Usage: bash agent-benchmark.sh --agent gemini [--tasks all|coding_generate,...] [--output results.json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER="$SCRIPT_DIR/benchmark-runner.py"
TASKS_FILE="$PROJECT_ROOT/config/benchmark-tasks.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ai-colab Agent Benchmark Runner (P4.5)             ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# Show help
show_help() {
    echo ""
    echo -e "${BLUE}Usage:${NC}"
    echo "  bash agent-benchmark.sh --agent <name> [options]"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --agent <name>       Agent to benchmark (gemini, qwen, claude, deepseek)"
    echo "  --tasks <list>       Comma-separated task IDs or 'all' (default: all)"
    echo "  --output <file>      Output file path for results JSON"
    echo "  --list-tasks         List available benchmark tasks"
    echo "  --compare <agents>   Compare multiple agents (comma-separated)"
    echo "  --help               Show this help message"
    echo ""
    echo -e "${BLUE}Available Agents:${NC}"
    echo "  gemini    - Google Gemini (Architect & Orchestrator)"
    echo "  qwen      - Alibaba Qwen (Assembly & Hardware)"
    echo "  claude    - Anthropic Claude (Generalist & Documentation)"
    echo "  deepseek  - DeepSeek (Logic & Optimization)"
    echo ""
    echo -e "${BLUE}Available Task Categories:${NC}"
    echo "  coding_*        - Code generation, debugging, refactoring"
    echo "  reasoning_*     - Logic puzzles, mathematical analysis"
    echo "  architecture_*  - System design"
    echo "  documentation_* - Technical writing, summarization"
}

# List available tasks
list_tasks() {
    if [[ ! -f "$TASKS_FILE" ]]; then
        print_error "Tasks file not found: $TASKS_FILE"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}Available Benchmark Tasks:${NC}"
    echo ""

    python3 -c "
import json
with open('$TASKS_FILE') as f:
    config = json.load(f)

categories = {}
for task_id, task in config.get('tasks', {}).items():
    cat = task.get('category', 'unknown')
    if cat not in categories:
        categories[cat] = []
    categories[cat].append((task_id, task.get('name', ''), task.get('description', '')))

for cat, tasks in categories.items():
    print(f'  {cat.upper()}:')
    for task_id, name, desc in tasks:
        print(f'    {task_id}: {name}')
        print(f'      {desc}')
    print()
"
}

# Compare multiple agents
compare_agents() {
    local agents_csv="$1"
    local tasks="${2:-all}"
    local output_dir="${3:-$PROJECT_ROOT/benchmark-results/comparisons}"

    IFS=',' read -ra agents <<< "$agents_csv"

    print_info "Comparing ${#agents[@]} agents: ${agents[*]}"
    print_info "Tasks: $tasks"
    echo ""

    local results=()

    for agent in "${agents[@]}"; do
        agent=$(echo "$agent" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        print_info "Benchmarking: $agent"

        local agent_output="$output_dir/benchmark_${agent}_$(date +%Y%m%d_%H%M%S).json"
        mkdir -p "$output_dir"

        python3 "$RUNNER" \
            --agent "$agent" \
            --tasks "$tasks" \
            --output "$agent_output" 2>&1

        results+=("$agent_output")
        echo ""
    done

    # Generate comparison report
    print_info "Generating comparison report..."

    python3 -c "
import json
import sys
from datetime import datetime

files = '''${results[*]}'''.split()
agents_data = []

for f in files:
    try:
        with open(f) as fh:
            data = json.load(fh)
            agents_data.append(data)
    except Exception as e:
        print(f'Warning: Could not load {f}: {e}')

if not agents_data:
    print('No valid results to compare')
    sys.exit(1)

print()
print('='*80)
print('AGENT COMPARISON REPORT')
print('='*80)
print()

# Header
header = f'{\"Agent\":<15} {\"Score\":<15} {\"Tasks Done\":<12} {\"Avg Time\":<10}'
print(header)
print('-'*80)

for data in agents_data:
    agent = data.get('agent', 'unknown')
    overall = data.get('overall', {})
    score = f'{overall.get(\"score\", 0)}/{overall.get(\"max_score\", 0)} ({overall.get(\"percentage\", 0)}%)'
    tasks = f'{overall.get(\"tasks_completed\", 0)}/{overall.get(\"tasks_completed\", 0) + overall.get(\"tasks_failed\", 0)}'
    avg_time = f'{overall.get(\"avg_duration_seconds\", 0):.1f}s'
    print(f'{agent:<15} {score:<15} {tasks:<12} {avg_time:<10}')

print()
print('Results saved to individual agent files in:', '$output_dir')
"
}

# ============================================================
# Main
# ============================================================

main() {
    local agent=""
    local tasks="all"
    local output=""
    local list_tasks=false
    local compare=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)
                agent="$2"
                shift 2
                ;;
            --tasks)
                tasks="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --list-tasks)
                list_tasks=true
                shift
                ;;
            --compare)
                compare="$2"
                shift 2
                ;;
            --help|-h)
                print_header
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

    # Handle list tasks
    if [[ "$list_tasks" == "true" ]]; then
        print_header
        list_tasks
        exit 0
    fi

    # Handle compare mode
    if [[ -n "$compare" ]]; then
        print_header
        compare_agents "$compare" "$tasks" "$output"
        exit 0
    fi

    # Validate agent
    if [[ -z "$agent" ]]; then
        print_error "Agent is required. Use --agent <name>"
        show_help
        exit 1
    fi

    # Validate runner exists
    if [[ ! -f "$RUNNER" ]]; then
        print_error "Benchmark runner not found: $RUNNER"
        exit 1
    fi

    # Run benchmark
    print_header
    echo ""
    print_info "Agent: $agent"
    print_info "Tasks: $tasks"
    [[ -n "$output" ]] && print_info "Output: $output"
    echo ""

    # Build command
    local cmd=(python3 "$RUNNER" --agent "$agent" --tasks "$tasks")
    if [[ -n "$output" ]]; then
        cmd+=(--output "$output")
    fi

    # Execute
    "${cmd[@]}"
}

main "$@"
