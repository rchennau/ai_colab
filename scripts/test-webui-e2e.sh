#!/usr/bin/env bash
# ai-colab WebUI E2E Test Runner
# Wrapper script for Playwright-based browser testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     ai-colab WebUI E2E Test Runner                       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if WebUI is running
echo -e "${YELLOW}Checking WebUI status...${NC}"
if ! curl -s --max-time 5 "http://localhost:8080/health" >/dev/null 2>&1; then
    echo -e "${RED}❌ WebUI is not running at http://localhost:8080${NC}"
    echo ""
    echo "Start WebUI first:"
    echo "  cd $PROJECT_ROOT"
    echo "  source ~/miniconda3/etc/profile.d/conda.sh"
    echo "  conda activate ai_agents"
    echo "  python3 webui/app.py &"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓ WebUI is running${NC}"
echo ""

# Check if Playwright is installed
echo -e "${YELLOW}Checking Playwright installation...${NC}"
if ! python3 -c "import playwright" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Playwright not installed. Installing...${NC}"
    pip install playwright >/dev/null 2>&1
    playwright install chromium >/dev/null 2>&1
    echo -e "${GREEN}✓ Playwright installed${NC}"
else
    echo -e "${GREEN}✓ Playwright installed${NC}"
fi
echo ""

# Create logs directory
mkdir -p "$LOG_DIR"

# Run tests
echo -e "${BLUE}Running E2E tests...${NC}"
echo ""

python3 "$SCRIPT_DIR/test-webui-playwright.py" "$@"

exit_code=$?

echo ""
if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  All E2E tests passed! ✓                                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  Some E2E tests failed. Check logs for details.          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
fi

exit $exit_code
