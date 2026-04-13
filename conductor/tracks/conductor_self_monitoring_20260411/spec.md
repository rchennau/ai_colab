# Track: Conductor Self-Monitoring (Phase 25)

**ID:** `conductor_self_monitoring_20260411`
**Created:** 2026-04-11
**Status:** In Progress 🔄
**Assigned:** @conductor, @architect
**Priority:** High

---

## Overview

Currently, the conductor monitors agents but doesn't monitor itself. If the conductor crashes, the entire fleet goes idle with no recovery mechanism. P25.1 adds self-monitoring capabilities: heartbeat to blackboard, auto-restart via watchdog, state recovery, and secondary agent detection.

**Theme:** "The conductor watches its own pulse"

---

## Tasks

### P25.1: Conductor Heartbeat

Conductor writes heartbeat to blackboard every 30 seconds:
- Key: `conductor_heartbeat` with timestamp and status
- Secondary agents can detect conductor absence (stale heartbeat)
- Alert mechanism when conductor is unresponsive

**Files:** `scripts/conductor-workflow.sh`, `scripts/conductor-heartbeat.sh`

### P25.2: Auto-Restart via Watchdog

Systemd/cron watchdog monitors conductor process:
- Detects conductor crash or hang
- Auto-restarts conductor with state recovery
- Exponential backoff on repeated failures (5s → 15s → 30s → 60s)

**Files:** `scripts/conductor-watchdog.sh`, `config/watchdog-config.json`

### P25.3: State Recovery

Conductor recovers state after restart:
- Event cursor recovery (last processed event ID)
- Task assignments recovery (in-progress tracks)
- Active agent list recovery
- Blackboard state validation

**Files:** `scripts/conductor-workflow.sh` (recovery logic)

### P25.4: Secondary Agent Detection

Secondary agents detect conductor absence:
- Monitor `conductor_heartbeat` key
- If stale (>90s), log alert and optionally pause agent activity
- Report conductor status to blackboard for human visibility

**Files:** `scripts/agent-wrapper.sh` (conductor monitoring logic)

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P25.1 (Heartbeat) | None |
| P25.2 (Watchdog) | P25.1 |
| P25.3 (Recovery) | P25.1, P25.2 |
| P25.4 (Detection) | P25.1 |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Heartbeat reliability | ≥ 99% successful writes | Heartbeat success rate |
| Restart time | < 10s from crash to recovery | Time to restart |
| State recovery | 100% cursor and task recovery | Recovery completeness |
| Detection latency | < 90s for conductor absence | Time to detect stale conductor |
