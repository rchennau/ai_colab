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

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

# Isolate environment
export PATH="$MOCK_DIR:$PATH"
export PROJECT_ROOT="$MOCK_DIR/workspace"
mkdir -p "$PROJECT_ROOT"
mkdir -p "$MOCK_DIR/hcom"
export HOME="$MOCK_DIR"

# Mocks
# 1. Mock docker
cat << 'EOF' > "$MOCK_DIR/docker"
#!/usr/bin/env bash
echo "docker $@" >> "$MOCK_LOG"
# Simulate agent progress output
if [[ "$*" == *"run"* ]]; then
    echo "PROGRESS: 20% | Initializing Container"
    echo "PROGRESS: 100% | Container Ready"
    exit 0
fi
EOF
chmod +x "$MOCK_DIR/docker"

# 2. Mock hcom
cat << 'EOF' > "$MOCK_DIR/hcom"
#!/usr/bin/env bash
echo "hcom $@" >> "$MOCK_LOG"
exit 0
EOF
chmod +x "$MOCK_DIR/hcom"

# 3. Mock date
cat << 'EOF' > "$MOCK_DIR/date"
#!/usr/bin/env bash
if [[ "$1" == "+%s" ]]; then echo "123456789"; else command date "$@"; fi
EOF
chmod +x "$MOCK_DIR/date"

export MOCK_LOG="$MOCK_DIR/mock.log"
touch "$MOCK_LOG"

print_test() { echo -e "${BLUE}▶ Testing: $1${NC}"; }
print_pass() { echo -e "  ${GREEN}✓ PASS${NC}"; }
print_fail() { echo -e "  ${RED}✗ FAIL: $1${NC}"; exit 1; }

# Test Case 1: Agent Wrapper Docker Command Generation
print_test "Agent Wrapper Docker Command Generation"

# Prepare environment
export HCOM_NAME="test_agent"
export GOOGLE_API_KEY="sk-123"

# Run wrapper in docker mode
bash "$PROJECT_ROOT/../scripts/agent-wrapper.sh" --docker gemini > /dev/null 2>&1 &
WRAPPER_PID=$!
sleep 2
kill $WRAPPER_PID 2>/dev/null || true

# Verify docker run command in log
# Should contain: -v workspace:/workspace, -v .hcom:/root/.hcom, -e HCOM_NAME, image name
if grep -q "docker run .* -v .*/workspace:/workspace" "$MOCK_LOG" && \
   grep -q "docker run .* -v .*/.hcom:/root/.hcom" "$MOCK_LOG" && \
   grep -q "docker run .* -e HCOM_NAME=test_agent" "$MOCK_LOG" && \
   grep -q "docker run .* aicolab/agent-gemini:latest" "$MOCK_LOG"; then
    print_pass
else
    print_fail "Docker run command is missing required arguments"
    cat "$MOCK_LOG"
fi

# Test Case 2: Progress Reporting from Container Logs
print_test "Progress Reporting from Container"

# The mock docker already emits PROGRESS lines.
# We check if blackboard_set was called (via utils.sh in the wrapper)
# Since we are mocking the wrapper's environment, let's verify if progress was logged.
# We'll use a simplified check: did the wrapper output show it parsed the progress?
# But since the wrapper runs in background, let's check the blackboard instead.

# Actually, the wrapper sources scripts/utils.sh, which uses sqlite3.
# Let's mock sqlite3 to see if blackboard_set was called for progress.
cat << 'EOF' > "$MOCK_DIR/sqlite3"
#!/usr/bin/env bash
echo "sqlite3 $@" >> "$MOCK_LOG"
EOF
chmod +x "$MOCK_DIR/sqlite3"

# Re-run test
truncate -s 0 "$MOCK_LOG"
bash "$PROJECT_ROOT/../scripts/agent-wrapper.sh" --docker gemini > /dev/null 2>&1 &
WRAPPER_PID=$!
sleep 2
kill $WRAPPER_PID 2>/dev/null || true

if grep -q "agent_progress_test_agent" "$MOCK_LOG" && grep -q "Initializing Container" "$MOCK_LOG"; then
    print_pass
else
    print_fail "Progress from container was not captured in blackboard"
    cat "$MOCK_LOG"
fi

echo -e "\n${GREEN}✓ All container isolation tests passed!${NC}"
