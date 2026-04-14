#!/usr/bin/env bash
# ai-colab Unified Test Harness
# Runs all test suites with configurable filtering and reporting
# Usage: bash scripts/test-all.sh [options]
#
# Options:
#   --ci              CI mode (no interactive prompts, machine-readable output)
#   --verbose         Verbose output with full test details
#   --skip-slow       Skip slow integration tests
#   --skip-integration Skip integration tests
#   --skip-webui      Skip Web UI tests
#   --skip-shell      Skip shell script tests
#   --skip-unit       Skip Python unit tests
#   --skip-docker     Skip Docker verification
#   --only <pattern>  Run only tests matching pattern
#   --help            Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests"
RESULTS_DIR="$PROJECT_ROOT/test-results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CI_MODE=false
VERBOSE=false
SKIP_SLOW=false
SKIP_INTEGRATION=false
SKIP_WEBUI=false
SKIP_SHELL=false
SKIP_UNIT=false
SKIP_DOCKER=false
ONLY_PATTERN=""

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Results tracking
declare -a TEST_RESULTS=()

# ============================================================
# Utility Functions
# ============================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

print_test_start() {
    echo -e "${CYAN}▶${NC} $1"
}

print_test_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED_TESTS++))
}

print_test_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED_TESTS++))
    TEST_RESULTS+=("FAIL:$1")
}

print_test_skip() {
    echo -e "${YELLOW}⊘ SKIP:${NC} $1"
    ((SKIPPED_TESTS++))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

record_result() {
    local test_name="$1"
    local status="$2"
    local duration="$3"
    local message="$4"

    if [[ "$CI_MODE" == "true" ]]; then
        echo "TEST_RESULT:$test_name:$status:${duration}s:$message"
    fi

    TEST_RESULTS+=("$status:$test_name:${duration}s")
}

# ============================================================
# Test Suites
# ============================================================

run_smoke_test() {
    print_header "Fast Smoke Test"

    local start_time=$(date +%s)

    # Skip if no conductor setup or hcom not available
    if ! command -v hcom >/dev/null 2>&1; then
        print_test_skip "hcom not installed (smoke test requires hcom)"
        record_result "smoke-test" "SKIP" "0" "hcom not installed"
        return 0
    fi

    local smoke_test="$TEST_DIR/smoke_test_fast.sh"
    if [[ ! -f "$smoke_test" ]]; then
        print_test_skip "Smoke test script not found"
        record_result "smoke-test" "SKIP" "0" "smoke_test_fast.sh not found"
        return 0
    fi

    print_test_start "Running fast smoke test (conductor event processing)..."
    chmod +x "$smoke_test"

    if bash "$smoke_test" 2>&1 | tee "$RESULTS_DIR/smoke-test.log"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test_pass "Fast smoke test passed (${duration}s)"
        record_result "smoke-test" "PASS" "$duration" "Conductor event processing verified"
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test_fail "Fast smoke test failed (${duration}s)"
        record_result "smoke-test" "FAIL" "$duration" "Conductor event processing failed"
    fi
}

run_unit_tests() {
    print_header "Python Unit Tests"

    if [[ "$SKIP_UNIT" == "true" ]]; then
        print_test_skip "Python unit tests (skipped by flag)"
        return 0
    fi

    local start_time=$(date +%s)
    local test_files=()

    # Find Python test files
    for f in "$TEST_DIR"/test_*.py; do
        if [[ -f "$f" ]]; then
            test_files+=("$f")
        fi
    done

    # Find MCP/RAG test files
    for f in "$TEST_DIR"/mcp_rag/*.py; do
        if [[ -f "$f" ]]; then
            test_files+=("$f")
        fi
    done

    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_test_skip "No Python test files found"
        return 0
    fi

    print_info "Found ${#test_files[@]} test file(s)"

    # Check if pytest is available
    if command -v pytest >/dev/null 2>&1; then
        print_test_start "Running pytest..."

        local cov_report=""
        if [[ "$CI_MODE" == "true" ]]; then
            cov_report="--cov=webui --cov=mcp --cov=rag --cov-report=xml:$RESULTS_DIR/coverage.xml"
        fi

        if pytest "${test_files[@]}" -v $cov_report \
            --junitxml="$RESULTS_DIR/unit-tests.xml" \
            --tb=short 2>&1 | tee "$RESULTS_DIR/unit-tests.log"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_test_pass "Python unit tests completed (${duration}s)"
            record_result "python-unit-tests" "PASS" "$duration" "All tests passed"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_test_fail "Python unit tests failed (${duration}s)"
            record_result "python-unit-tests" "FAIL" "$duration" "Some tests failed"
        fi
    else
        print_info "pytest not available, skipping Python tests"
        print_test_skip "pytest not installed"
    fi
}

run_shell_tests() {
    print_header "Shell Script Tests"

    if [[ "$SKIP_SHELL" == "true" ]]; then
        print_test_skip "Shell script tests (skipped by flag)"
        return 0
    fi

    local start_time=$(date +%s)
    local test_files=()

    # Find shell test files
    for f in "$TEST_DIR"/test_*.sh; do
        if [[ -f "$f" ]]; then
            # Skip webui tests if requested
            if [[ "$SKIP_WEBUI" == "true" && "$f" == *"webui"* ]]; then
                continue
            fi
            test_files+=("$f")
        fi
    done

    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_test_skip "No shell test files found"
        return 0
    fi

    print_info "Found ${#test_files[@]} shell test file(s)"

    local suite_passed=0
    local suite_failed=0

    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "$test_file" .sh)
        print_test_start "Running $test_name..."

        local file_start=$(date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            chmod +x "$test_file"
            if bash "$test_file" 2>&1 | tee "$RESULTS_DIR/${test_name}.log"; then
                local file_end=$(date +%s)
                local duration=$((file_end - file_start))
                print_test_pass "$test_name (${duration}s)"
                record_result "$test_name" "PASS" "$duration" ""
                ((suite_passed++))
            else
                local file_end=$(date +%s)
                local duration=$((file_end - file_start))
                print_test_fail "$test_name (${duration}s)"
                record_result "$test_name" "FAIL" "$duration" "Test failed"
                ((suite_failed++))
            fi
        else
            chmod +x "$test_file"
            if bash "$test_file" >/dev/null 2>&1; then
                local file_end=$(date +%s)
                local duration=$((file_end - file_start))
                print_test_pass "$test_name (${duration}s)"
                record_result "$test_name" "PASS" "$duration" ""
                ((suite_passed++))
            else
                local file_end=$(date +%s)
                local duration=$((file_end - file_start))
                print_test_fail "$test_name (${duration}s)"
                record_result "$test_name" "FAIL" "$duration" "Test failed"
                ((suite_failed++))
            fi
        fi
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $suite_failed -eq 0 ]]; then
        print_test_pass "All shell tests completed (${duration}s)"
    else
        print_test_fail "$suite_failed shell test(s) failed (${duration}s)"
    fi
}

run_webui_tests() {
    print_header "Web UI Tests"

    if [[ "$SKIP_WEBUI" == "true" ]]; then
        print_test_skip "Web UI tests (skipped by flag)"
        return 0
    fi

    local start_time=$(date +%s)
    local test_file="$TEST_DIR/test_webui.sh"

    if [[ ! -f "$test_file" ]]; then
        print_test_skip "Web UI test file not found"
        return 0
    fi

    print_test_start "Running Web UI test suite..."

    chmod +x "$test_file"
    if bash "$test_file" 2>&1 | tee "$RESULTS_DIR/webui-tests.log"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test_pass "Web UI tests completed (${duration}s)"
        record_result "webui-tests" "PASS" "$duration" ""
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test_fail "Web UI tests failed (${duration}s)"
        record_result "webui-tests" "FAIL" "$duration" "Some tests failed"
    fi
}

run_docker_tests() {
    print_header "Docker Build & Verification"

    if [[ "$SKIP_DOCKER" == "true" ]]; then
        print_test_skip "Docker tests (skipped by flag)"
        return 0
    fi

    if [[ "$SKIP_SLOW" == "true" ]]; then
        print_test_skip "Docker tests (skipped - slow)"
        return 0
    fi

    local start_time=$(date +%s)

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        print_test_skip "Docker not installed"
        return 0
    fi

    print_test_start "Building Docker image..."

    if docker build -t ai-colab:test "$PROJECT_ROOT" >/dev/null 2>&1; then
        print_test_pass "Docker image built successfully"

        # Run container and check health
        print_test_start "Running health check..."
        if docker run -d --name test-ai-colab -p 8080:8080 ai-colab:test >/dev/null 2>&1; then
            sleep 10
            if curl -f http://localhost:8080/health >/dev/null 2>&1; then
                print_test_pass "Docker health check passed"
                record_result "docker-health" "PASS" "" ""
            else
                print_test_fail "Docker health check failed"
                record_result "docker-health" "FAIL" "" "Health endpoint not responding"
            fi
            docker stop test-ai-colab >/dev/null 2>&1
            docker rm test-ai-colab >/dev/null 2>&1
        else
            print_test_fail "Docker container failed to start"
            record_result "docker-container" "FAIL" "" "Container failed to start"
        fi
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test_fail "Docker build failed (${duration}s)"
        record_result "docker-build" "FAIL" "$duration" "Build failed"
    fi
}

run_integration_tests() {
    print_header "Integration Tests"

    if [[ "$SKIP_INTEGRATION" == "true" ]]; then
        print_test_skip "Integration tests (skipped by flag)"
        return 0
    fi

    if [[ "$SKIP_SLOW" == "true" ]]; then
        print_test_skip "Integration tests (skipped - slow)"
        return 0
    fi

    local start_time=$(date +%s)
    local test_files=()

    # Find integration test files
    for f in "$TEST_DIR"/mcp_rag/test_*.py "$TEST_DIR"/test_integration.py; do
        if [[ -f "$f" ]]; then
            test_files+=("$f")
        fi
    done

    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_test_skip "No integration test files found"
        return 0
    fi

    print_info "Found ${#test_files[@]} integration test file(s)"

    if command -v pytest >/dev/null 2>&1; then
        print_test_start "Running integration tests..."

        if pytest "${test_files[@]}" -v --tb=short 2>&1 | tee "$RESULTS_DIR/integration-tests.log"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_test_pass "Integration tests completed (${duration}s)"
            record_result "integration-tests" "PASS" "$duration" ""
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_test_fail "Integration tests failed (${duration}s)"
            record_result "integration-tests" "FAIL" "$duration" "Some tests failed"
        fi
    else
        print_test_skip "pytest not available for integration tests"
    fi
}

# ============================================================
# Summary & Reporting
# ============================================================

generate_summary() {
    print_header "Test Execution Summary"

    local total=$((PASSED_TESTS + FAILED_TESTS))

    echo ""
    echo -e "${BLUE}Results:${NC}"
    echo -e "  ${GREEN}✓ Passed: $PASSED_TESTS${NC}"
    echo -e "  ${RED}✗ Failed: $FAILED_TESTS${NC}"
    echo -e "  ${YELLOW}⊘ Skipped: $SKIPPED_TESTS${NC}"
    echo -e "  Total executed: $total"
    echo ""

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Failed tests:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == FAIL:* ]]; then
                echo -e "  ${RED}✗ ${result#FAIL:}${NC}"
            fi
        done
        echo ""
    fi

    # Generate JUnit-style summary for CI
    if [[ "$CI_MODE" == "true" ]]; then
        echo "CI_SUMMARY_START"
        echo "total_executed=$total"
        echo "total_passed=$PASSED_TESTS"
        echo "total_failed=$FAILED_TESTS"
        echo "total_skipped=$SKIPPED_TESTS"
        echo "CI_SUMMARY_END"

        # Write JSON summary
        cat > "$RESULTS_DIR/summary.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_executed": $total,
  "total_passed": $PASSED_TESTS,
  "total_failed": $FAILED_TESTS,
  "total_skipped": $SKIPPED_TESTS,
  "results": [
$(for i in "${!TEST_RESULTS[@]}"; do
    local entry="${TEST_RESULTS[$i]}"
    local status="${entry%%:*}"
    local rest="${entry#*:}"
    echo "    {\"status\": \"$status\", \"test\": \"$rest\"}$([ $i -lt $((${#TEST_RESULTS[@]}-1)) ] && echo ",")"
done)
  ]
}
EOF
    fi

    # Overall status
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS test(s) failed${NC}"
        return 1
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ci) CI_MODE=true; shift ;;
            --verbose) VERBOSE=true; shift ;;
            --skip-slow) SKIP_SLOW=true; shift ;;
            --skip-integration) SKIP_INTEGRATION=true; shift ;;
            --skip-webui) SKIP_WEBUI=true; shift ;;
            --skip-shell) SKIP_SHELL=true; shift ;;
            --skip-unit) SKIP_UNIT=true; shift ;;
            --skip-docker) SKIP_DOCKER=true; shift ;;
            --only) ONLY_PATTERN="$2"; shift 2 ;;
            --help)
                head -12 "$0" | tail -11
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    print_header "ai-colab Unified Test Harness"
    echo ""
    echo -e "${BLUE}Project Root:${NC} $PROJECT_ROOT"
    echo -e "${BLUE}CI Mode:${NC} $CI_MODE"
    echo -e "${BLUE}Verbose:${NC} $VERBOSE"
    echo ""

    local start_time=$(date +%s)

    # Run test suites
    run_smoke_test
    run_unit_tests
    run_shell_tests
    run_webui_tests
    run_docker_tests
    run_integration_tests

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    echo -e "${BLUE}Total execution time: ${total_duration}s${NC}"

    # Generate summary
    generate_summary
    local exit_code=$?

    exit $exit_code
}

main "$@"
