#!/bin/bash
#
# MCP & RAG Test Runner
# Runs all tests and generates reports
#
# Usage: ./scripts/run-tests.sh [--unit] [--integration] [--security] [--benchmarks] [--all]
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Activate virtual environment if it exists
if [[ -f "$PROJECT_ROOT/.venv/bin/activate" ]]; then
    source "$PROJECT_ROOT/.venv/bin/activate"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}PASS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARN:${NC} $1"
}

print_error() {
    echo -e "${RED}FAIL:${NC} $1"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run unit tests
run_unit_tests() {
    print_info "Running Unit Tests..."
    echo ""

    cd "$PROJECT_ROOT"

    # Check if pytest is installed
    if ! python -c "import pytest" 2>/dev/null; then
        print_warning "pytest not installed. Install with: pip install -r requirements-test.txt"
        return 1
    fi

    # MCP tests
    if [[ -d "$PROJECT_ROOT/mcp/tests" ]]; then
        print_info "MCP Server Tests:"
        if python -m pytest mcp/tests/ -v --tb=short 2>/dev/null; then
            print_success "MCP tests passed"
            ((TESTS_PASSED++))
        else
            print_error "MCP tests failed"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    fi

    # RAG tests
    if [[ -d "$PROJECT_ROOT/rag/tests" ]]; then
        print_info "RAG System Tests:"
        if python -m pytest rag/tests/ -v --tb=short 2>/dev/null; then
            print_success "RAG tests passed"
            ((TESTS_PASSED++))
        else
            print_error "RAG tests failed"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    fi

    echo ""
}

# Run integration tests
run_integration_tests() {
    print_info "Running Integration Tests..."
    echo ""

    cd "$PROJECT_ROOT"

    if [[ -f "$PROJECT_ROOT/tests/mcp_rag/test_integration.py" ]]; then
        if python tests/mcp_rag/test_integration.py; then
            print_success "Integration tests passed"
            ((TESTS_PASSED++))
        else
            print_error "Integration tests failed"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    else
        print_warning "Integration test file not found"
    fi

    echo ""
}

# Run security audit
run_security_audit() {
    print_info "Running Security Audit..."
    echo ""

    cd "$PROJECT_ROOT"

    if [[ -f "$PROJECT_ROOT/tests/mcp_rag/security_audit.py" ]]; then
        if python tests/mcp_rag/security_audit.py; then
            print_success "Security audit passed"
            ((TESTS_PASSED++))
        else
            print_error "Security audit found issues"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    else
        print_warning "Security audit script not found"
    fi

    echo ""
}

# Run benchmarks
run_benchmarks() {
    print_info "Running Performance Benchmarks..."
    echo ""

    cd "$PROJECT_ROOT"

    if [[ -f "$PROJECT_ROOT/tests/mcp_rag/test_integration.py" ]]; then
        python tests/mcp_rag/test_integration.py --benchmarks 2>/dev/null || \
        python -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
from tests.mcp_rag.test_integration import run_benchmarks
run_benchmarks()
"
    else
        print_warning "Benchmark script not found"
    fi

    echo ""
}

# Show help
show_help() {
    cat << EOF
MCP & RAG Test Runner

Usage: $0 [options]

Options:
  --unit         Run unit tests only
  --integration  Run integration tests only
  --security     Run security audit only
  --benchmarks   Run benchmarks only
  --all          Run all tests (default)
  --help         Show this help

Examples:
  $0 --all           # Run all tests
  $0 --unit          # Run unit tests only
  $0 --security      # Run security audit

EOF
}

# Main
main() {
    local run_unit=false
    local run_integration=false
    local run_security=false
    local run_benchmarks=false
    
    # Default to all if no args
    if [[ $# -eq 0 ]]; then
        run_unit=true
        run_integration=true
        run_security=true
        run_benchmarks=true
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit)
                run_unit=true
                shift
                ;;
            --integration)
                run_integration=true
                shift
                ;;
            --security)
                run_security=true
                shift
                ;;
            --benchmarks)
                run_benchmarks=true
                shift
                ;;
            --all)
                run_unit=true
                run_integration=true
                run_security=true
                run_benchmarks=true
                shift
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
    
    # Header
    echo ""
    echo "============================================================"
    echo "  MCP & RAG Test Suite"
    echo "  Project: ai-colab"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"
    echo ""
    
    # Run requested tests
    if [[ "$run_unit" == "true" ]]; then
        run_unit_tests
    fi
    
    if [[ "$run_integration" == "true" ]]; then
        run_integration_tests
    fi
    
    if [[ "$run_security" == "true" ]]; then
        run_security_audit
    fi
    
    if [[ "$run_benchmarks" == "true" ]]; then
        run_benchmarks
    fi
    
    # Summary
    echo ""
    echo "============================================================"
    echo "  Test Summary"
    echo "============================================================"
    echo ""
    echo "  Tests Run:    $TESTS_RUN"
    echo "  Passed:       $TESTS_PASSED"
    echo "  Failed:       $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        print_success "All tests passed!"
        exit 0
    else
        print_error "$TESTS_FAILED test(s) failed"
        exit 1
    fi
}

main "$@"
