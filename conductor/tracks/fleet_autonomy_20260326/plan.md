# Plan: Fleet Autonomy & Self-Healing

## Phase 1: Core Infrastructure (Health 2.0)
- [x] **Task**: Enhance `scripts/utils.sh` with `report_health()` function that writes JSON metrics to the Blackboard.
- [x] **Task**: Update `start_heartbeat()` to call `report_health()` and include a simple latency check (ping or API call).
- [x] **Task**: Refactor `scripts/agent-wrapper.sh` to use the enhanced heartbeat.

## Phase 2: Conductor Watchdog
- [x] **Task**: Implement a "Fleet Watchdog" loop in `scripts/conductor-workflow.sh`.
- [x] **Task**: Add logic to detect stale heartbeats and attempt to signal the agent's wrapper for restart.
- [x] **Task**: Implement a basic "failover" lookup table in the Conductor.

## Phase 3: Agent Self-Diagnostics
- [x] **Task**: Enhance `scripts/nemo-cli.py` and other connectors to report API error codes to the health metrics.
- [x] **Task**: Update agent wrappers to catch exit codes and log "Last words" to the Blackboard before restarting.

## Phase 4: Verification & UX
- [x] **Task**: Add a "Fleet Health" section to the Conductor Dashboard TUI.
- [x] **Task**: Create `tests/test_fleet_autonomy.sh` and `tests/test_fleet_recovery.sh` to verify recovery.
- [x] **Task**: Final documentation update.
