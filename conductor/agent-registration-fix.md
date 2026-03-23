# Plan: Improve hcom Registration and Dashboard Status Reporting

## Objective
Ensure that all agents (including conductor and model agents) correctly register with hcom, maintain heartbeats, and report their status to the hcom TUI. Fix inconsistencies in naming and launch logic.

## Proposed Changes

### 1. `scripts/agent-wrapper.sh`
- Move `register_hcom` call after argument parsing.
- Handle `--name` flag in argument parsing by setting `HCOM_NAME`.
- Ensure `HCOM_NAME` is used consistently for registration and heartbeat.

### 2. `scripts/conductor/launch.sh`
- Ensure `HCOM_NAME` is set before calling `agent-wrapper.sh`.
- Fix the use of `--name` argument (it will now be handled by `agent-wrapper.sh`).

### 3. `scripts/conductor-workflow.sh`
- Use `HCOM_NAME` consistently instead of mismatched `AGENT_NAME`.
- Fix `register_hcom` call to avoid redundant suffix.
- Use `HCOM_NAME` for `hcom events sub` and `hcom listen`.

### 4. `scripts/dashboard-launch.sh`
- Update `reconnect()` to check if requested windows (Conductor, Bridge) are missing from the existing session and add them if necessary.
- Ensure proper environment variables are passed.

### 5. `scripts/utils.sh`
- Ensure `register_hcom` is robust.

## Verification
1. Run `launch.sh` and select both dashboard and conductor.
2. Verify that `hcom-dashboard` session has a `conductor` window.
3. Run `hcom list` and verify that all requested agents (gemini, qwen, conductor) are listed as "listening".
4. Verify that the heartbeat maintains the "listening" status even if the main agent process is busy or restarting.
