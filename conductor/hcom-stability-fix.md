# Plan: HCOM Stability and Noise Reduction (Heartbeat v2)

## Objective
Fix the "exit:timeout" status cycling (flapping) in the hcom TUI and reduce the event noise caused by frequent status broadcasts. This will ensure the TUI remains responsive and only shows meaningful updates.

## Proposed Changes

### 1. `scripts/utils.sh`
- **Modify `start_heartbeat()`**: 
    - Switch from `hcom start --as "$HCOM_NAME"` to `hcom status --name "$HCOM_NAME"`. 
    - This updates the agent's "last seen" timestamp without emitting a "created" lifecycle event or displacing active sessions (like `hcom listen`).
    - Increase the interval from 10 seconds to 20 seconds. 20s is frequent enough to prevent the default 30-60s timeout but slow enough to reduce overhead.

### 2. `scripts/conductor-workflow.sh`
- **Smart Status Broadcast**:
    - Track the last broadcasted progress percentage and active track.
    - Only call `hcom send @all` if:
        a) The progress percentage has changed.
        b) The active track has changed.
        c) More than 10 minutes have passed since the last broadcast (keep-alive).
- **Increase Loop Interval**: 
    - Change the `hcom listen --timeout` from 10 seconds to 30 seconds.
    - This reduces the frequency of blackboard syncs and event polling, which are currently running too fast.

### 3. `scripts/agent-wrapper.sh`
- **Increase Restart Delay**:
    - Increase `RESTART_DELAY` from 5s to 10s to give `hcom` more time to clean up old sessions before a new one starts.

## Detailed Steps

### Step 1: Update `scripts/utils.sh`
```bash
start_heartbeat() {
    local tool_name="${1:-agent}"
    if [ -n "${HCOM_NAME:-}" ]; then
        # Lightweight heartbeat via 'hcom status' in background.
        # This updates the 'last seen' timestamp without emitting 'created' events.
        (
            while true; do
                # hcom status --name refreshes the heartbeat for the given name
                hcom status --name "$HCOM_NAME" > /dev/null 2>&1 || true
                sleep 20
            done
        ) &
        export HEARTBEAT_PID=$!
        return 0
    fi
    return 1
}
```

### Step 2: Update `scripts/conductor-workflow.sh`
Add state tracking for broadcasts:
```bash
LAST_BROADCAST_PCT=""
LAST_BROADCAST_TRACK=""
LAST_BROADCAST_TIME=0

...

# Inside sync_blackboard_status:
    # Only broadcast if something changed or 10 mins passed
    local current_time=$(date +%s)
    if [[ "$percent" != "$LAST_BROADCAST_PCT" || "$next_track" != "$LAST_BROADCAST_TRACK" || $((current_time - LAST_BROADCAST_TIME)) -gt 600 ]]; then
        hcom send @all --intent inform --thread "plan-sync" -- "Status: $complete/$total tracks complete ($percent%). Next up: ${next_track:-All complete}."
        LAST_BROADCAST_PCT="$percent"
        LAST_BROADCAST_TRACK="$next_track"
        LAST_BROADCAST_TIME=$current_time
    fi
```

### Step 3: Verify the fix
1. Launch the dashboard.
2. Observe `hcom events --all --type life` to ensure no "created" events are firing every 20s.
3. Observe the TUI to ensure agents stay `ready` or `listening` without flickering to `exit:timeout`.
4. Verify that the conductor doesn't spam the TUI with status updates unless progress is made.

## Risks
- If `hcom status --name` is not enough to keep the agent from being marked "stale" in older hcom versions, we might need to use `hcom list --name "$HCOM_NAME"`. (Testing suggests `status` works).
- Longer intervals might delay the detection of a truly crashed agent, but 20-30s is a good balance.
