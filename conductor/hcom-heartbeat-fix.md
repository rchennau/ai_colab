# Plan: Fix HCOM Telemetry and Heartbeat Reliability

## Objective
Fix the "exit:timeout" status cycling in the hcom TUI for all agents. The current implementation only registers an agent once, which causes hcom to mark it as timed out after a short period. We need a continuous heartbeat that doesn't interfere with the interactive LLM CLI sessions.

## Proposed Changes

### 1. `scripts/utils.sh`
- Modify `start_heartbeat()` to launch a background loop that periodically refreshes the agent's status using `hcom start`.
- Ensure the heartbeat loop is associated with the current process and cleaned up on exit.
- Use a 10-second interval for the heartbeat to ensure the TUI stays responsive.
- Avoid using `hcom listen` in the heartbeat loop to prevent "stealing" messages from interactive agents.

### 2. `scripts/agent-wrapper.sh`
- Ensure that `HCOM_NAME` is properly handled and passed to the heartbeat.
- Improve the cleanup function to kill the background heartbeat process.
- Increase the `RESTART_DELAY` slightly to 5 seconds to reduce churn if an agent is repeatedly crashing due to configuration issues (like missing API keys).

### 3. `scripts/conductor-workflow.sh`
- Ensure it also benefits from the improved heartbeat if it doesn't already. (It currently uses `hcom listen` which provides its own heartbeat, but a secondary one might be safer).

## Detailed Steps

### Step 1: Update `scripts/utils.sh`
Update `start_heartbeat` to:
```bash
start_heartbeat() {
    local tool_name="${1:-agent}"
    if [ -n "${HCOM_NAME:-}" ]; then
        # Continuous heartbeat via 'hcom start' in background.
        # This keeps the status 'ready' in TUI without stealing messages like 'listen' would.
        (
            while true; do
                hcom start --as "$HCOM_NAME" > /dev/null 2>&1 || true
                sleep 10
            done
        ) &
        export HEARTBEAT_PID=$!
        return 0
    fi
    return 1
}
```

### Step 2: Update `scripts/agent-wrapper.sh`
Update the cleanup trap to kill the heartbeat:
```bash
cleanup() {
    # Kill background heartbeat if it exists
    if [ -n "${HEARTBEAT_PID:-}" ]; then
        kill "$HEARTBEAT_PID" 2>/dev/null || true
    fi
    ...
}
```

### Step 3: Verify the fix
1. Launch the dashboard.
2. Observe the `hcom` TUI to ensure agents stay `ready` and do not flicker to `exit:timeout`.
3. Verify that interactive messages still work (i.e., the heartbeat isn't intercepting them).

## Risks
- If `hcom start` itself is heavy or causes flickering in the TUI, the 10-second interval might be too frequent. However, for 0.7.5 it should be fine.
- Background processes might accumulate if not properly cleaned up. The `trap cleanup EXIT` should handle this.
