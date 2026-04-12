# Track: Conductor Failover & Self-Healing (P5.5)

**ID:** `conductor_failover_20260411`  
**Created:** 2026-04-11  
**Status:** In Progress 🔄  
**Assigned:** @conductor, @architect  
**Priority:** High  

---

## Overview

Currently, if the conductor crashes, the entire fleet stops receiving task assignments. There's no automatic recovery or failover mechanism. P5.5 implements self-healing orchestration with conductor auto-restart and agent promotion to temporary conductor.

**Theme:** "Never lose the conductor"

---

## Tasks

### P5.5.1: Conductor Health Monitoring

Monitor conductor health via heartbeat and latency checks:
- Conductor writes heartbeat to blackboard every loop iteration
- Monitor detects stale conductor heartbeats (>2x loop interval)
- Track conductor restart count and failure patterns

**Files:** `scripts/conductor-failover.sh`

### P5.5.2: Auto-Restart with State Recovery

Automatically restart conductor when detected as down:
- Preserve event cursor, task assignments, and blackboard state
- Restart conductor with same configuration
- Exponential backoff for restart attempts (10s → 30s → 60s → 120s)
- Maximum restart attempts before escalation

**Files:** `scripts/conductor-failover.sh`

### P5.5.3: Agent Promotion to Temporary Conductor

If conductor cannot restart, promote a healthy agent:
- Select healthiest agent (based on circuit breaker status)
- Promoted agent takes over conductor responsibilities
- Minimal conductor functionality: track monitoring, task assignment
- Original conductor reclaim when it recovers

**Files:** `scripts/conductor-failover.sh`, `scripts/conductor-workflow.sh`

### P5.5.4: State Recovery After Failover

Ensure state consistency after failover:
- Verify event cursor is preserved
- Re-assign uncompleted tasks
- Re-broadcast fleet status
- Log failover event for audit trail

**Files:** `scripts/conductor-failover.sh`

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P5.5.1 (Health Monitoring) | P16.5 (Circuit Breaker) |
| P5.5.2 (Auto-Restart) | P5.5.1 |
| P5.5.3 (Agent Promotion) | P5.5.2 |
| P5.5.4 (State Recovery) | P5.5.3 |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Conductor detection time | < 2x loop interval | Time from crash to detection |
| Auto-restart success rate | ≥ 95% | Successful restarts / total crashes |
| State recovery completeness | 100% of critical state preserved | Post-restart state verification |
| Agent promotion time | < 60s from detection to promotion | Timing measurement |
