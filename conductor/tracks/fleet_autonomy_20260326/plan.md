# Plan: Fleet Autonomy & Self-Healing

## Phase 1: Core Infrastructure (Health 2.0)
- [ ] **Task**: Enhance `scripts/utils.sh` with `report_health()` function that writes JSON metrics to the Blackboard.
- [ ] **Task**: Update `start_heartbeat()` to call `report_health()` and include a simple latency check (ping or API call).
- [ ] **Task**: Refactor `scripts/agent-wrapper.sh` to use the enhanced heartbeat.

## Phase 2: Conductor Watchdog
- [ ] **Task**: Implement a "Fleet Watchdog" loop in `scripts/conductor-workflow.sh`.
- [ ] **Task**: Add logic to detect stale heartbeats and attempt to signal the agent's wrapper for restart.
- [ ] **Task**: Implement a basic "failover" lookup table in the Conductor.

## Phase 3: Agent Self-Diagnostics
- [ ] **Task**: Enhance `scripts/nemo-cli.py` and other connectors to report API error codes to the health metrics.
- [ ] **Task**: Update agent wrappers to catch exit codes and log "Last words" to the Blackboard before restarting.

## Phase 4: Verification & UX
- [ ] **Task**: Add a "Fleet Health" section to the Conductor Dashboard TUI.
- [ ] **Task**: Create `tests/test_fleet_autonomy.sh` to simulate agent crashes and verify recovery.
- [ ] **Task**: Final documentation update.
