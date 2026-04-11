#!/usr/bin/env bash
# Test Suite: MQTT Broker (P16.6.1)
# Tests: Docker service health, certificate generation, persistence

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

assert_not_empty() {
    local value="$1"
    local message="$2"

    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Value is empty"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# ============================================================
# Tests
# ============================================================

test_mosquitto_config_exists() {
    echo -e "\n${CYAN}▶${NC} Test: Mosquitto configuration files exist"

    assert_file_exists "$PROJECT_ROOT/docker/mosquitto/mosquitto.conf" "Mosquitto config exists"
    assert_file_exists "$PROJECT_ROOT/docker/mosquitto/entrypoint.sh" "Entrypoint script exists"
}

test_docker_compose_has_mqtt_service() {
    echo -e "\n${CYAN}▶${NC} Test: Docker Compose has MQTT service definition"

    local compose_file="$PROJECT_ROOT/docker-compose.yml"

    if [[ -f "$compose_file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} docker-compose.yml exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} docker-compose.yml not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Check for mqtt service definition
    if grep -q "ai-colab-mqtt" "$compose_file"; then
        echo -e "${GREEN}✓ PASS:${NC} MQTT service defined in docker-compose.yml"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} MQTT service not found in docker-compose.yml"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Check for mqtt profile
    if grep -q "profile.*mqtt\|mqtt.*profile" "$compose_file"; then
        echo -e "${GREEN}✓ PASS:${NC} MQTT profile configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} MQTT profile not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_config_toml_has_mqtt_settings() {
    echo -e "\n${CYAN}▶${NC} Test: config.toml has MQTT settings"

    local config_file="$PROJECT_ROOT/config.toml"

    if [[ -f "$config_file" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} config.toml exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} config.toml not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Check for self-hosted broker URL
    if grep -q "mqtts://localhost:8883" "$config_file"; then
        echo -e "${GREEN}✓ PASS:${NC} Self-hosted broker URL configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Self-hosted broker URL not found"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Check for TLS settings
    if grep -q "tls_enabled" "$config_file"; then
        echo -e "${GREEN}✓ PASS:${NC} TLS setting present"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} TLS setting missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    # Check for username/password placeholders
    if grep -q "username" "$config_file" && grep -q "password" "$config_file"; then
        echo -e "${GREEN}✓ PASS:${NC} Auth credentials configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Auth credentials missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_certificate_generation_script() {
    echo -e "\n${CYAN}▶${NC} Test: Certificate generation script exists and is executable"

    local cert_script="$PROJECT_ROOT/scripts/generate-certs.sh"

    assert_file_exists "$cert_script" "Certificate generation script exists"

    if [[ -x "$cert_script" ]]; then
        echo -e "${GREEN}✓ PASS:${NC} Certificate script is executable"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Certificate script is not executable"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_mosquitto_config_has_tls() {
    echo -e "\n${CYAN}▶${NC} Test: Mosquitto config has TLS settings"

    local config="$PROJECT_ROOT/docker/mosquitto/mosquitto.conf"

    if grep -q "listener 8883" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} TLS listener configured on port 8883"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} TLS listener not configured"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    if grep -q "cafile" "$config" && grep -q "certfile" "$config" && grep -q "keyfile" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} TLS certificate paths configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} TLS certificate paths missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    if grep -q "tls_version" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} TLS version constraint configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} TLS version constraint missing"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_mosquitto_config_has_auth() {
    echo -e "\n${CYAN}▶${NC} Test: Mosquitto config has authentication settings"

    local config="$PROJECT_ROOT/docker/mosquitto/mosquitto.conf"

    if grep -q "allow_anonymous false" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} Anonymous connections disabled"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Anonymous connections not disabled"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    if grep -q "password_file" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} Password file configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Password file not configured"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_mosquitto_config_has_persistence() {
    echo -e "\n${CYAN}▶${NC} Test: Mosquitto config has persistence settings"

    local config="$PROJECT_ROOT/docker/mosquitto/mosquitto.conf"

    if grep -q "persistence true" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} Persistence enabled"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Persistence not enabled"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))

    if grep -q "persistence_location" "$config"; then
        echo -e "${GREEN}✓ PASS:${NC} Persistence location configured"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} Persistence location not configured"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_documentation_exists() {
    echo -e "\n${CYAN}▶${NC} Test: MQTT security documentation exists"

    assert_file_exists "$PROJECT_ROOT/docs/mqtt-security-setup.md" "MQTT security setup guide exists"
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  MQTT Broker Test Suite (P16.6)                     ${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_mosquitto_config_exists
    test_docker_compose_has_mqtt_service
    test_config_toml_has_mqtt_settings
    test_certificate_generation_script
    test_mosquitto_config_has_tls
    test_mosquitto_config_has_auth
    test_mosquitto_config_has_persistence
    test_documentation_exists

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
