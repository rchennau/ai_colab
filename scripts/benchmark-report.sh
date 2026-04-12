#!/usr/bin/env bash
# ai-colab Benchmark Report Generator (P4.5)
# Generates comparison reports from benchmark results
# Usage: bash benchmark-report.sh [--compare agent1,agent2,...] [--latest] [--all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmark-results"
REPORTS_DIR="$PROJECT_ROOT/docs/benchmark-reports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ai-colab Benchmark Report Generator (P4.5)         ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1" >&2; }

# List available benchmark results
list_results() {
    if [[ ! -d "$RESULTS_DIR" ]]; then
        print_info "No benchmark results found. Run agent-benchmark.sh first."
        return 0
    fi

    echo ""
    echo -e "${BLUE}Available Benchmark Results:${NC}"
    echo ""

    for f in "$RESULTS_DIR"/benchmark_*.json; do
        if [[ -f "$f" ]]; then
            local agent timestamp
            agent=$(basename "$f" | sed 's/benchmark_//;s/_[0-9]*_[0-9]*\.json//')
            timestamp=$(basename "$f" | grep -o '[0-9]*_[0-9]*' | head -1)
            echo "  $agent ($timestamp)"
        fi
    done
}

# Generate a comparison report
generate_report() {
    local agents_csv="$1"
    local report_file="$REPORTS_DIR/comparison_$(date +%Y%m%d_%H%M%S).md"

    mkdir -p "$REPORTS_DIR"

    IFS=',' read -ra agents <<< "$agents_csv"

    # Find latest results for each agent
    local result_files=()
    for agent in "${agents[@]}"; do
        agent=$(echo "$agent" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local latest
        latest=$(ls -t "$RESULTS_DIR"/benchmark_${agent}_*.json 2>/dev/null | head -1)

        if [[ -z "$latest" ]]; then
            print_error "No results found for agent: $agent"
            return 1
        fi

        result_files+=("$latest")
    done

    # Generate markdown report
    python3 -c "
import json
import sys
from datetime import datetime

files = '''${result_files[*]}'''.split()
agents_data = []

for f in files:
    try:
        with open(f) as fh:
            agents_data.append(json.load(fh))
    except Exception as e:
        print(f'Warning: Could not load {f}: {e}')

if not agents_data:
    print('No valid results to compare')
    sys.exit(1)

report_file = '$report_file'

with open(report_file, 'w') as f:
    f.write('# Agent Benchmark Comparison Report\\n\\n')
    f.write(f'**Generated:** {datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")}\\n\\n')

    f.write('## Summary\\n\\n')
    f.write('| Agent | Score | Tasks | Avg Time | Total Time |\\n')
    f.write('|-------|-------|-------|----------|------------|\\n')

    for data in sorted(agents_data, key=lambda x: x.get('overall', {}).get('percentage', 0), reverse=True):
        agent = data.get('agent', 'unknown')
        overall = data.get('overall', {})
        score = f'{overall.get(\"score\", 0)}/{overall.get(\"max_score\", 0)} ({overall.get(\"percentage\", 0)}%)'
        tasks = f'{overall.get(\"tasks_completed\", 0)}/{overall.get(\"tasks_completed\", 0) + overall.get(\"tasks_failed\", 0)}'
        avg_time = f'{overall.get(\"avg_duration_seconds\", 0):.1f}s'
        total_time = f'{overall.get(\"total_duration_seconds\", 0):.1f}s'
        f.write(f'| {agent} | {score} | {tasks} | {avg_time} | {total_time} |\\n')

    f.write('\\n## Category Breakdown\\n\\n')

    # Collect all categories
    all_categories = set()
    for data in agents_data:
        for cat in data.get('categories', {}).keys():
            all_categories.add(cat)

    for cat in sorted(all_categories):
        f.write(f'### {cat.title()}\\n\\n')
        f.write('| Agent | Score |\\n')
        f.write('|-------|-------|\\n')

        for data in sorted(agents_data, key=lambda x: x.get('categories', {}).get(cat, {}).get('score', 0), reverse=True):
            agent = data.get('agent', 'unknown')
            cat_data = data.get('categories', {}).get(cat, {})
            score = f'{cat_data.get(\"score\", 0)}/{cat_data.get(\"max\", 0)}'
            pct = round(cat_data.get('score', 0) / cat_data.get('max', 1) * 100, 1)
            f.write(f'| {agent} | {score} ({pct}%) |\\n')

        f.write('\\n')

    f.write('## Detailed Results\\n\\n')

    for data in agents_data:
        agent = data.get('agent', 'unknown')
        f.write(f'### {agent}\\n\\n')

        for result in data.get('results', []):
            task_id = result.get('task_id', 'unknown')
            score = result.get('score', 0)
            max_score = result.get('max_score', 0)
            duration = result.get('duration_seconds', 0)
            passed = result.get('criteria_passed', 0)
            failed = result.get('criteria_failed', 0)
            error = result.get('error', '')

            f.write(f'**{task_id}**: {score}/{max_score} ({passed} passed, {failed} failed) - {duration:.1f}s\\n')
            if error:
                f.write(f'  - Error: {error[:100]}\\n')
            f.write('\\n')

print(f'Report generated: {report_file}')
"
}

# ============================================================
# Main
# ============================================================

main() {
    local compare=""
    local list=false
    local latest=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --compare)
                compare="$2"
                shift 2
                ;;
            --list)
                list=true
                shift
                ;;
            --latest)
                latest=true
                shift
                ;;
            --help|-h)
                print_header
                echo ""
                echo "Usage: bash benchmark-report.sh [options]"
                echo ""
                echo "Options:"
                echo "  --compare <agents>   Compare agents (comma-separated)"
                echo "  --list               List available benchmark results"
                echo "  --latest             Show latest results summary"
                echo "  --help               Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    print_header

    if [[ "$list" == "true" ]]; then
        list_results
        exit 0
    fi

    if [[ -n "$compare" ]]; then
        generate_report "$compare"
        exit 0
    fi

    # Default: show latest results
    if [[ "$latest" == "true" ]]; then
        echo ""
        echo "Latest results:"
        for agent_dir in "$RESULTS_DIR"/benchmark_*.json; do
            if [[ -f "$agent_dir" ]]; then
                echo "  $(basename "$agent_dir")"
            fi
        done
        exit 0
    fi

    # Default: list results
    list_results
}

main "$@"
