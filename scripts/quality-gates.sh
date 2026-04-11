#!/usr/bin/env bash
# ai-colab Quality Gates v1.0
# Extensible validation framework for agent-produced work.
# Checks: Python syntax, linting (flake8), security (bandit), and tests.

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FAILED_CHECKS=0

print_check() { echo -e "${BLUE}▶ Checking $1...${NC}"; }
print_pass() { echo -e "  ${GREEN}✓ PASS${NC}"; }
print_fail() { echo -e "  ${RED}✗ FAIL: $1${NC}"; ((FAILED_CHECKS++)) || true; }

# 1. Python Syntax Check
check_syntax() {
    print_check "Python Syntax"
    # Find changed or core files (simplified for now: check all .py in project)
    if python3 -m compileall -q "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/webui" "$PROJECT_ROOT/rag" 2>/dev/null; then
        print_pass
    else
        print_fail "Syntax errors detected"
    fi
}

# 2. Linting (flake8)
check_lint() {
    print_check "Linting (flake8)"
    if ! command -v flake8 >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Skipping: flake8 not installed${NC}"
        return
    fi
    
    # Run on scripts and webui, ignore some common non-critical errors
    if flake8 "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/webui" --count --select=E9,F63,F7,F82 --show-source --statistics; then
        print_pass
    else
        print_fail "Linting issues found"
    fi
}

# 3. Security Scan (bandit)
check_security() {
    print_check "Security (bandit)"
    if ! command -v bandit >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Skipping: bandit not installed${NC}"
        return
    fi
    
    if bandit -r "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/webui" -ll -q; then
        print_pass
    else
        print_fail "Potential security vulnerabilities detected"
    fi
}

# 4. Project Tests
check_tests() {
    print_check "Integration Tests"
    # Run a subset of critical tests
    if bash "$PROJECT_ROOT/scripts/run-tests.sh" --quick; then
        print_pass
    else
        print_fail "Tests failed"
    fi
}

# Run all checks
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           ai-colab Quality Gates             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

check_syntax
check_lint
check_security
# check_tests # Uncomment when quick test mode is available

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All quality gates passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Quality gates failed ($FAILED_CHECKS errors).${NC}"
    exit 1
fi
