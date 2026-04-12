#!/usr/bin/env bash
# Test Suite: Docker Deployment (P4.2)
# Tests: docker-compose syntax, service definitions, volume config, profiles

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Test Helpers
# ============================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected to contain: '$needle'"
        echo -e "  Actual: '$haystack'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  File not found: '$file'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_executable() {
    local file="$1"
    local message="$2"

    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Not executable: '$file'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_docker_compose_syntax() {
    echo -e "\n${CYAN}▶${NC} Test: Docker Compose syntax is valid"

    local result
    result=$(docker compose config --quiet 2>&1)

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Docker Compose syntax is valid"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Docker Compose syntax error: $result"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_core_services_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Core services are defined"

    local services
    services=$(docker compose config --services 2>/dev/null)

    local core_services=("hub" "mqtt")
    local all_found=true

    for service in "${core_services[@]}"; do
        if echo "$services" | grep -q "^$service$"; then
            echo -e "${GREEN}✓ PASS:${NC} Service '$service' defined"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Service '$service' not found"
            ((TESTS_FAILED++))
            all_found=false
        fi
        ((TESTS_RUN++))
    done
}

test_agent_services_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Agent services are defined"

    local services
    services=$(docker compose --profile agents config --services 2>/dev/null)

    local agent_services=("agent-gemini" "agent-qwen" "agent-claude" "agent-deepseek")
    local all_found=true

    for service in "${agent_services[@]}"; do
        if echo "$services" | grep -q "^$service$"; then
            echo -e "${GREEN}✓ PASS:${NC} Agent service '$service' defined"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Agent service '$service' not found"
            ((TESTS_FAILED++))
            all_found=false
        fi
        ((TESTS_RUN++))
    done
}

test_volumes_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Persistent volumes are defined"

    local volumes
    volumes=$(docker compose config --volumes 2>/dev/null)

    local required_volumes=("ai-colab-config" "ai-colab-state" "hcom-data" "mqtt-data" "mqtt-certs")

    for volume in "${required_volumes[@]}"; do
        if echo "$volumes" | grep -q "$volume"; then
            echo -e "${GREEN}✓ PASS:${NC} Volume '$volume' defined"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL:${NC} Volume '$volume' not found"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

test_networks_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Networks are defined"

    local networks
    networks=$(docker compose config --networks 2>/dev/null)

    if echo "$networks" | grep -q "ai-colab-network"; then
        echo -e "${GREEN}✓ PASS:${NC} Network 'ai-colab-network' defined"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Network 'ai-colab-network' not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_agent_dockerfiles_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Agent Dockerfiles exist"

    local agent_dockerfiles=(
        "docker/agents/base/Dockerfile"
        "docker/agents/gemini/Dockerfile"
        "docker/agents/qwen/Dockerfile"
        "docker/agents/claude/Dockerfile"
        "docker/agents/deepseek/Dockerfile"
    )

    for dockerfile in "${agent_dockerfiles[@]}"; do
        assert_file_exists "$PROJECT_ROOT/$dockerfile" "$dockerfile exists"
    done
}

test_agent_wrapper_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Agent wrapper script exists"

    assert_file_exists "$PROJECT_ROOT/docker/agents/agent-wrapper.sh" "Agent wrapper script exists"
    assert_executable "$PROJECT_ROOT/docker/agents/agent-wrapper.sh" "Agent wrapper is executable"
}

test_env_example_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Environment example file exists"

    assert_file_exists "$PROJECT_ROOT/.env.example" ".env.example exists"
}

test_deployment_docs_exist() {
    echo -e "\n${CYAN}▶${NC} Test: Deployment documentation exists"

    assert_file_exists "$PROJECT_ROOT/docs/docker-deployment.md" "Docker deployment docs exist"
}

test_health_checks_defined() {
    echo -e "\n${CYAN}▶${NC} Test: Health checks are defined"

    local config
    config=$(docker compose config 2>/dev/null)

    if echo "$config" | grep -q "healthcheck"; then
        echo -e "${GREEN}✓ PASS:${NC} Health checks defined in compose file"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} No health checks found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Docker Deployment Test Suite (P4.2)                ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_docker_compose_syntax
    test_core_services_defined
    test_agent_services_defined
    test_volumes_defined
    test_networks_defined
    test_agent_dockerfiles_exist
    test_agent_wrapper_exists
    test_env_example_exists
    test_deployment_docs_exist
    test_health_checks_defined

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
