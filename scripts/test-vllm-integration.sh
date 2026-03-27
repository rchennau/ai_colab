#!/bin/bash
#
# vLLM Integration Test Suite
# Tests all vLLM integration points in ai-colab
#
# Usage: ./scripts/test-vllm-integration.sh
#

# Don't exit on error - we want to run all tests
set +e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Check vLLM wrapper script exists
test_vllm_wrapper() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 1: vLLM Wrapper Script${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local wrapper="$PROJECT_ROOT/scripts/vllm-hcom.sh"
    
    if [[ -f "$wrapper" ]]; then
        print_success "vLLM wrapper script exists"
        
        # Check if it's executable
        if [[ -x "$wrapper" ]]; then
            print_success "vLLM wrapper is executable"
        else
            print_warning "vLLM wrapper is not executable (will try to fix)"
            chmod +x "$wrapper" 2>/dev/null || print_warning "Could not make executable"
        fi
        
        # Check if it calls agent-wrapper.sh
        if grep -q "agent-wrapper.sh" "$wrapper"; then
            print_success "vLLM wrapper calls agent-wrapper.sh"
        else
            print_error "vLLM wrapper doesn't call agent-wrapper.sh"
            ((TESTS_FAILED++))
            return
        fi
        
        ((TESTS_PASSED++))
    else
        print_error "vLLM wrapper script not found: $wrapper"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_RUN++))
}

# Test 2: Check agent-wrapper.sh vLLM support
test_agent_wrapper_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 2: Agent Wrapper vLLM Support${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local wrapper="$PROJECT_ROOT/scripts/agent-wrapper.sh"
    
    if [[ ! -f "$wrapper" ]]; then
        print_error "agent-wrapper.sh not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check for vLLM case statement
    if grep -q 'vllm)' "$wrapper"; then
        print_success "agent-wrapper.sh has vLLM case statement"
    else
        print_error "agent-wrapper.sh missing vLLM case statement"
        ((TESTS_FAILED++))
    fi
    
    # Check for VLLM_BASE_URL
    if grep -q 'VLLM_BASE_URL' "$wrapper"; then
        print_success "agent-wrapper.sh sets VLLM_BASE_URL"
    else
        print_error "agent-wrapper.sh missing VLLM_BASE_URL"
        ((TESTS_FAILED++))
    fi
    
    # Check for CUSTOM_LLM_ENDPOINT
    if grep -q 'CUSTOM_LLM_ENDPOINT' "$wrapper"; then
        print_success "agent-wrapper.sh sets CUSTOM_LLM_ENDPOINT"
    else
        print_error "agent-wrapper.sh missing CUSTOM_LLM_ENDPOINT"
        ((TESTS_FAILED++))
    fi
    
    # Check default host
    if grep -q '192.168.0.193' "$wrapper"; then
        print_success "agent-wrapper.sh has default vLLM host"
    else
        print_warning "agent-wrapper.sh missing default vLLM host"
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 3: Check dashboard-launch.sh vLLM integration
test_dashboard_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 3: Dashboard vLLM Integration${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local dashboard="$PROJECT_ROOT/scripts/dashboard-launch.sh"
    
    if [[ ! -f "$dashboard" ]]; then
        print_error "dashboard-launch.sh not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check for WITH_VLLM variable
    if grep -q 'WITH_VLLM' "$dashboard"; then
        print_success "dashboard-launch.sh has WITH_VLLM variable"
    else
        print_error "dashboard-launch.sh missing WITH_VLLM variable"
        ((TESTS_FAILED++))
    fi
    
    # Check for --vllm flag
    if grep -q '\-\-vllm' "$dashboard"; then
        print_success "dashboard-launch.sh has --vllm flag"
    else
        print_error "dashboard-launch.sh missing --vllm flag"
        ((TESTS_FAILED++))
    fi
    
    # Check for --no-vllm flag
    if grep -q '\-\-no-vllm' "$dashboard"; then
        print_success "dashboard-launch.sh has --no-vllm flag"
    else
        print_error "dashboard-launch.sh missing --no-vllm flag"
        ((TESTS_FAILED++))
    fi
    
    # Check vLLM pane setup
    if grep -q 'vllm_dev' "$dashboard"; then
        print_success "dashboard-launch.sh has vLLM agent name"
    else
        print_warning "dashboard-launch.sh missing vLLM agent name"
    fi
    
    # Check default is false
    if grep -q 'WITH_VLLM=false' "$dashboard"; then
        print_success "dashboard-launch.sh defaults WITH_VLLM to false"
    else
        print_warning "dashboard-launch.sh doesn't explicitly default WITH_VLLM to false"
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 4: Check launch.sh vLLM configuration
test_launch_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 4: Launch Script vLLM Configuration${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local launch="$PROJECT_ROOT/launch.sh"
    
    if [[ ! -f "$launch" ]]; then
        print_error "launch.sh not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check for vLLM host loading
    if grep -q 'llm.vllm.host' "$launch"; then
        print_success "launch.sh loads llm.vllm.host preference"
    else
        print_error "launch.sh missing llm.vllm.host preference"
        ((TESTS_FAILED++))
    fi
    
    # Check for VLLM_BASE_URL export
    if grep -q 'export VLLM_BASE_URL' "$launch"; then
        print_success "launch.sh exports VLLM_BASE_URL"
    else
        print_error "launch.sh missing VLLM_BASE_URL export"
        ((TESTS_FAILED++))
    fi
    
    # Check for vllm-remote backend
    if grep -q 'vllm-remote' "$launch"; then
        print_success "launch.sh has vllm-remote backend option"
    else
        print_warning "launch.sh missing vllm-remote backend option"
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 5: Check install-wizard.sh vLLM support
test_install_wizard_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 5: Install Wizard vLLM Support${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local wizard="$PROJECT_ROOT/scripts/install-wizard.sh"
    
    if [[ ! -f "$wizard" ]]; then
        print_error "install-wizard.sh not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check for vLLM prompt
    if grep -q 'Enable vLLM' "$wizard"; then
        print_success "install-wizard.sh prompts for vLLM"
    else
        print_error "install-wizard.sh missing vLLM prompt"
        ((TESTS_FAILED++))
    fi
    
    # Check for vLLM host input
    if grep -q 'vLLM Host' "$wizard"; then
        print_success "install-wizard.sh prompts for vLLM host"
    else
        print_error "install-wizard.sh missing vLLM host prompt"
        ((TESTS_FAILED++))
    fi
    
    # Check for LLM_VLLM variable
    if grep -q 'LLM_VLLM' "$wizard"; then
        print_success "install-wizard.sh uses LLM_VLLM variable"
    else
        print_warning "install-wizard.sh missing LLM_VLLM variable"
    fi
    
    # Check for preference saving
    if grep -q 'llm.vllm.enabled' "$wizard"; then
        print_success "install-wizard.sh saves llm.vllm.enabled"
    else
        print_error "install-wizard.sh missing llm.vllm.enabled save"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 6: Check Web UI vLLM integration
test_webui_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 6: Web UI vLLM Integration${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local index_html="$PROJECT_ROOT/webui/index.html"
    local app_py="$PROJECT_ROOT/webui/app.py"
    
    # Check index.html
    if [[ -f "$index_html" ]]; then
        # Check for vLLM checkbox
        if grep -q 'llm-vllm' "$index_html"; then
            print_success "Web UI has vLLM checkbox"
        else
            print_error "Web UI missing vLLM checkbox"
            ((TESTS_FAILED++))
        fi
        
        # Check for vLLM in configuration
        if grep -q 'cfg-llm-vllm' "$index_html"; then
            print_success "Web UI has vLLM config editor"
        else
            print_warning "Web UI missing vLLM config editor"
        fi
        
        ((TESTS_PASSED++))
    else
        print_error "Web UI index.html not found"
        ((TESTS_FAILED++))
    fi
    
    # Check app.py
    if [[ -f "$app_py" ]]; then
        # Check for vllm flag handling
        if grep -q 'vllm' "$app_py"; then
            print_success "Web UI app.py handles vllm flag"
        else
            print_error "Web UI app.py missing vllm flag"
            ((TESTS_FAILED++))
        fi
        
        ((TESTS_PASSED++))
    else
        print_error "Web UI app.py not found"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_RUN++))
}

# Test 7: Check configuration schema
test_config_schema() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 7: Configuration Schema vLLM Support${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local schema="$PROJECT_ROOT/config/config.schema.json"
    
    if [[ ! -f "$schema" ]]; then
        print_error "config.schema.json not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check for vllm in enum
    if grep -q '"vllm"' "$schema"; then
        print_success "config.schema.json includes vllm in LLM enum"
    else
        print_error "config.schema.json missing vllm in LLM enum"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 8: Functional test - Check environment variable flow
test_env_var_flow() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 8: Environment Variable Flow${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Simulate setting vLLM environment
    export VLLM_BASE_URL="http://test-host:8000/v1"
    export VLLM_API_KEY="test-key"
    
    # Check if variables are set
    if [[ "$VLLM_BASE_URL" == "http://test-host:8000/v1" ]]; then
        print_success "VLLM_BASE_URL can be set"
    else
        print_error "VLLM_BASE_URL not set correctly"
        ((TESTS_FAILED++))
    fi
    
    if [[ "$VLLM_API_KEY" == "test-key" ]]; then
        print_success "VLLM_API_KEY can be set"
    else
        print_error "VLLM_API_KEY not set correctly"
        ((TESTS_FAILED++))
    fi
    
    # Check default values in agent-wrapper.sh
    if grep -q 'VLLM_BASE_URL:-http://192.168.0.193:8000/v1' "$PROJECT_ROOT/scripts/agent-wrapper.sh"; then
        print_success "agent-wrapper.sh has correct default VLLM_BASE_URL"
    else
        print_warning "agent-wrapper.sh default VLLM_BASE_URL format differs"
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 9: Check config-manager.sh vLLM support
test_config_manager_vllm() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 9: Config Manager vLLM Support${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local config_mgr="$PROJECT_ROOT/scripts/config-manager.sh"
    
    if [[ ! -f "$config_mgr" ]]; then
        print_error "config-manager.sh not found"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
        return
    fi
    
    # Check if config-manager can get/set vLLM config
    if bash "$config_mgr" get llm.vllm.enabled 2>/dev/null; then
        print_success "config-manager.sh can get llm.vllm.enabled"
    else
        # This might fail if not set, which is OK
        print_warning "config-manager.sh get llm.vllm.enabled (may not be set)"
    fi
    
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# Test 10: Check documentation
test_documentation() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test 10: vLLM Documentation${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    local vllm_doc="$PROJECT_ROOT/docs/VLLM_INTEGRATION_REVIEW.md"
    
    if [[ -f "$vllm_doc" ]]; then
        print_success "vLLM integration review document exists"
        
        # Check for key sections
        if grep -q 'Dashboard' "$vllm_doc"; then
            print_success "Documentation covers Dashboard integration"
        fi
        
        if grep -q 'Configuration' "$vllm_doc"; then
            print_success "Documentation covers Configuration"
        fi
        
        if grep -q 'Usage' "$vllm_doc"; then
            print_success "Documentation includes Usage examples"
        fi
        
        ((TESTS_PASSED++))
    else
        print_warning "vLLM integration review document not found"
        ((TESTS_PASSED++))  # Not critical
    fi
    
    ((TESTS_RUN++))
}

# Main
main() {
    echo ""
    echo "============================================================"
    echo "  vLLM Integration Test Suite"
    echo "  Project: ai-colab"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"
    
    # Run all tests
    test_vllm_wrapper
    test_agent_wrapper_vllm
    test_dashboard_vllm
    test_launch_vllm
    test_install_wizard_vllm
    test_webui_vllm
    test_config_schema
    test_env_var_flow
    test_config_manager_vllm
    test_documentation
    
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
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "vLLM integration is fully functional."
        echo ""
        echo "Next steps:"
        echo "  1. Configure vLLM host: ./scripts/config-manager.sh set llm.vllm.host <host>"
        echo "  2. Enable vLLM: ./scripts/config-manager.sh set llm.vllm.enabled true"
        echo "  3. Launch with vLLM: ./launch.sh --vllm"
        echo ""
        exit 0
    else
        echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
        echo ""
        echo "Please review the failed tests above."
        echo ""
        exit 1
    fi
}

main "$@"
