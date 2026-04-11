#!/usr/bin/env bash
# Test harness for Portable Python isolation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_ENV_MGR="$PROJECT_ROOT/scripts/python-env-manager.sh"

echo -e "${BLUE}Running Portable Python Isolation Tests...${NC}"

# Create mock dir
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
export PATH="$MOCK_DIR:/usr/bin:/bin"

# Mock uv
cat << 'EOF' > "$MOCK_DIR/uv"
#!/usr/bin/env bash
echo "uv $@" >> "$MOCK_LOG"
if [[ "$1" == "python" && "$2" == "install" ]]; then
    exit 0
fi
if [[ "$1" == "venv" ]]; then
    mkdir -p .venv/bin
    touch .venv/bin/activate
    exit 0
fi
EOF
chmod +x "$MOCK_DIR/uv"

export MOCK_LOG="$MOCK_DIR/mock.log"
touch "$MOCK_LOG"

# Run with PORTABLE=true
export PORTABLE=true
export PROJECT_ROOT="$MOCK_DIR"
bash "$PYTHON_ENV_MGR" create

# Verify mock calls
if grep -q "uv python install 3.11" "$MOCK_LOG" && grep -q "uv venv $MOCK_DIR/.venv --python 3.11" "$MOCK_LOG"; then
    echo -e "  ${GREEN}✓ PASS:${NC} Portable python installation logic verified"
else
    echo -e "  ${RED}✗ FAIL:${NC} Portable python installation logic failed"
    echo "Expected: uv venv $MOCK_DIR/.venv --python 3.11"
    echo "Actual calls in $MOCK_LOG:"
    cat "$MOCK_LOG"
    exit 1
fi

echo -e "${GREEN}All portable python tests passed! 🚀${NC}"
