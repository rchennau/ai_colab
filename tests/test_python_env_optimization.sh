#!/usr/bin/env bash
# Test harness for Python Environment Optimization

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_ENV_MGR="$PROJECT_ROOT/scripts/python-env-manager.sh"

test_passed=0
test_failed=0

assert_eq() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo -e "  ${GREEN}✓ PASS:${NC} $description"
        ((test_passed++))
    else
        echo -e "  ${RED}✗ FAIL:${NC} $description"
        echo -e "    Actual:   $actual"
        echo -e "    Expected: $expected"
        ((test_failed++))
    fi
}

# Create a temporary mock directory
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
# Isolate PATH: only include mock dir and basic system tools
export PATH="$MOCK_DIR:/usr/bin:/bin:/usr/sbin:/sbin"

echo -e "${BLUE}Running Python Environment Manager Tests...${NC}"

# Test 1: uv detection
touch "$MOCK_DIR/uv" && chmod +x "$MOCK_DIR/uv"
assert_eq "$("$PYTHON_ENV_MGR" detect)" "uv" "UV detection"
rm "$MOCK_DIR/uv"

# Test 2: Conda detection
touch "$MOCK_DIR/conda" && chmod +x "$MOCK_DIR/conda"
assert_eq "$("$PYTHON_ENV_MGR" detect)" "conda" "Conda detection"
rm "$MOCK_DIR/conda"

# Test 3: Venv detection
# (Mocking python3 -m venv)
mkdir -p "$MOCK_DIR"
cat << 'EOF' > "$MOCK_DIR/python3"
#!/usr/bin/env bash
if [[ "$1" == "-m" && "$2" == "venv" && "$3" == "--help" ]]; then
    exit 0
fi
exit 1
EOF
chmod +x "$MOCK_DIR/python3"
assert_eq "$("$PYTHON_ENV_MGR" detect)" "venv" "Venv detection"
rm "$MOCK_DIR/python3"

# Test 4: Pixi detection
touch "$MOCK_DIR/pixi" && chmod +x "$MOCK_DIR/pixi"
assert_eq "$("$PYTHON_ENV_MGR" detect)" "pixi" "Pixi detection"
rm "$MOCK_DIR/pixi"

# Test 5: Activation command (uv)
touch "$MOCK_DIR/uv" && chmod +x "$MOCK_DIR/uv"
assert_eq "$("$PYTHON_ENV_MGR" activate-cmd)" "source \"$PROJECT_ROOT/.venv/bin/activate\"" "UV activation command"
rm "$MOCK_DIR/uv"

# Test 6: Activation command (conda)
touch "$MOCK_DIR/conda" && chmod +x "$MOCK_DIR/conda"
assert_eq "$("$PYTHON_ENV_MGR" activate-cmd)" "conda activate \"ai-colab\"" "Conda activation command"
rm "$MOCK_DIR/conda"

# Summary
echo -e "\n${BLUE}Test Summary:${NC}"
echo -e "  ${GREEN}Passed:${NC} $test_passed"
echo -e "  ${RED}Failed:${NC} $test_failed"

if [[ $test_failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed! 🚀${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
