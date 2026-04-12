#!/usr/bin/env bash
# Test harness for Milestone 23: Containerized Agents (P4.1)
# Verifies the agent wrapper correctly spawns and communicates with Docker containers.

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
MOCK_LOG="$MOCK_DIR/mock.log"
touch "$MOCK_LOG"

print_test() { echo -e "${BLUE}▶ Testing: $1${NC}"; }
print_pass() { echo -e "  ${GREEN}✓ PASS${NC}"; }
print_fail() { echo -e "  ${RED}✗ FAIL: $1${NC}"; exit 1; }

# Isolate environment
export PATH="$MOCK_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
export REAL_PROJECT_ROOT="${REAL_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export PROJECT_ROOT="$MOCK_DIR/workspace"
export REAL_PROJECT_ROOT
mkdir -p "$PROJECT_ROOT/scripts"
cp "$REAL_PROJECT_ROOT/scripts/agent-wrapper.sh" "$PROJECT_ROOT/scripts/"
cp "$REAL_PROJECT_ROOT/scripts/utils.sh" "$PROJECT_ROOT/scripts/utils.sh.real"

# Create mock utils.sh
cat << 'EOF' > "$PROJECT_ROOT/scripts/utils.sh"
#!/usr/bin/env bash
echo "DEBUG: utils.sh sourced. PATH=$PATH" >> "$MOCK_LOG"
has_command() { command -v "$1" >/dev/null 2>&1; }
detect_project_root() { echo "$PROJECT_ROOT"; }
log_info() { echo "[INFO] $@"; }
log_success() { echo "[SUCCESS] $@"; }
log_warn() { echo "[WARN] $@"; }
log_error() { echo "[ERROR] $@"; }
get_ms() { echo "123456789"; }
blackboard_get() { echo "None"; }
blackboard_set() { echo "sqlite3 set $1 $2" >> "$MOCK_LOG"; }
blackboard_list() { echo ""; }
report_health() { echo "health $1 $2 $3" >> "$MOCK_LOG"; }
report_progress() { echo "sqlite3 progress $1 $2" >> "$MOCK_LOG"; }
register_hcom() { echo "register $1" >> "$MOCK_LOG"; }
start_heartbeat() { echo "heartbeat $1" >> "$MOCK_LOG"; }
agent_record_failure() { echo "fail $1" >> "$MOCK_LOG"; }
agent_should_retry() { echo "true"; }
agent_calc_backoff() { echo "1"; }
EOF
chmod +x "$PROJECT_ROOT/scripts/utils.sh"

# Ensure hcom config dir exists
mkdir -p "$MOCK_DIR/.hcom"
export HOME="$MOCK_DIR"

# Mocks
# ... (mocks remain the same)
# 1. Mock docker
cat << 'EOF' > "$MOCK_DIR/docker"
#!/usr/bin/env bash
# Simulate agent progress output to stdout for the wrapper to parse
echo "PROGRESS: 10% | Starting Mock Container"
echo "PROGRESS: 50% | Running Task"
echo "PROGRESS: 100% | Completed"
# Log the call itself to our mock log
echo "docker $@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$MOCK_DIR/docker"

# 2. Mock hcom (the binary)
cat << 'EOF' > "$MOCK_DIR/hcom"
#!/usr/bin/env bash
echo "hcom $@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$MOCK_DIR/hcom"

# 3. Mock date
cat << 'EOF' > "$MOCK_DIR/date"
#!/usr/bin/env bash
echo "123456789"
EOF
chmod +x "$MOCK_DIR/date"

# Re-run test for progress
# We must ensure all required variables are exported for the subshell
export HCOM_NAME="test_agent"
export GOOGLE_API_KEY="sk-123"
export SCRIPT_DIR="$PROJECT_ROOT/scripts"
export MOCK_LOG
export MOCK_DIR
export PROJECT_ROOT

bash -x "$PROJECT_ROOT/scripts/agent-wrapper.sh" gemini --docker --name "$HCOM_NAME" --model "gemini-3.0" > "$MOCK_DIR/progress_exec.log" 2>&1 &
WRAPPER_PID=$!
sleep 4
kill $WRAPPER_PID 2>/dev/null || true

echo "DEBUG: MOCK_LOG content after background run:"
cat "$MOCK_LOG"

if grep -q "sqlite3 progress 10 Starting Mock Container" "$MOCK_LOG" && grep -q "sqlite3 progress 50 Running Task" "$MOCK_LOG"; then
    print_pass
else
    print_fail "Progress from container was not captured in blackboard"
    echo "DEBUG: MOCK_LOG content above"
    echo "DEBUG: Trace Log (progress_exec.log) content:"
    [ -f "$MOCK_DIR/progress_exec.log" ] && cat "$MOCK_DIR/progress_exec.log" || echo "Trace log not found"
    exit 1
fi

echo -e "\n${GREEN}✓ All container isolation tests passed!${NC}"
