#!/usr/bin/env bash
# Project Migration Tool Verification
# Tests detection of existing AI/LLM integrations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UTILS="$PROJECT_ROOT/scripts/utils.sh"
MIGRATE_TOOL="$PROJECT_ROOT/scripts/migrate-project.sh"

source "$UTILS"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    echo -e "\n${BLUE}TEST:${NC} $1"
}

test_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

ui_banner "Project Migration Verification" "${BLUE}"

# Create a mock project structure for testing
MOCK_PROJECT="/tmp/ai-colab-mock-project"
rm -rf "$MOCK_PROJECT"
mkdir -p "$MOCK_PROJECT"

# ============================================
# Test 1: Detection of MCP Configs
# ============================================
test_start "MCP Configuration Detection"

mkdir -p "$MOCK_PROJECT/.cursor"
echo '{"mcpServers": {}}' > "$MOCK_PROJECT/.cursor/mcp.json"

# Run detection only
OUTPUT=$(bash "$MIGRATE_TOOL" "$MOCK_PROJECT" --detect-only 2>&1)

if echo "$OUTPUT" | grep -q ".cursor/mcp.json"; then
    test_pass "Detected Cursor MCP configuration"
else
    test_fail "Failed to detect Cursor MCP configuration"
fi

# ============================================
# Test 2: Detection of Product Plans
# ============================================
test_start "Product Plan Detection"

mkdir -p "$MOCK_PROJECT/conductor"
touch "$MOCK_PROJECT/conductor/product.md"
touch "$MOCK_PROJECT/conductor/tracks.md"

OUTPUT=$(bash "$MIGRATE_TOOL" "$MOCK_PROJECT" --detect-only 2>&1)

if echo "$OUTPUT" | grep -q "conductor/product.md"; then
    test_pass "Detected existing Conductor artifacts"
else
    test_fail "Failed to detect Conductor artifacts"
fi

# ============================================
# Test 3: Detection of Python MCP Servers
# ============================================
test_start "Python MCP Server Detection"

mkdir -p "$MOCK_PROJECT/my_special_agent"
echo "import mcp" > "$MOCK_PROJECT/my_special_agent/server.py"

OUTPUT=$(bash "$MIGRATE_TOOL" "$MOCK_PROJECT" --detect-only 2>&1)

if echo "$OUTPUT" | grep -q "Python MCP server implementation"; then
    test_pass "Detected custom Python MCP server"
else
    test_fail "Failed to detect custom Python MCP server"
fi

# Cleanup
rm -rf "$MOCK_PROJECT"

# ============================================
# Summary
# ============================================
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed! Migration tool verified.${NC}"
    exit 0
else
    exit 1
fi
