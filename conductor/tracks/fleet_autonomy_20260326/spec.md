# Specification: Fleet Autonomy & Self-Healing

## 1. Objective
To transform the current agent fleet into a resilient, self-healing system capable of monitoring its own health and recovering from failures across a distributed "Hub and Spoke" architecture.

## 2. Requirements

### 2.1 Distributed Heartbeat (Health 2.0)
- **Enhanced Metrics**: Heartbeats must report more than just process existence. They must include:
    - `latency`: Round-trip time to the backend API.
    - `load`: Current active tasks or token usage.
    - `status`: Detailed state (e.g., `ready`, `rate_limited`, `degraded`).
- **Standardized Storage**: Metrics should be stored in the Blackboard (`hcom-kv`) using a predictable key pattern: `fleet_health_<agent_name>`.

### 2.2 Autonomous Recovery
- **Watchdog Implementation**: The Conductor Agent must act as a watchdog for the fleet.
- **Auto-Restart Logic**: If an agent heartbeat is missing for > 2x the interval, the Conductor should attempt a restart.
- **Failover Routing**: If a critical Spoke (e.g., `@nemoclaw`) remains down, the Conductor should automatically re-route its pending tasks to a designated backup agent.

### 2.3 Self-Diagnostic Loop
- **Error Propagation**: Agents must catch backend API errors (429, 500, 503) and log them to the Blackboard.
- **Adaptive Backoff**: Agents should autonomously increase their heartbeat interval when rate-limited.

### 2.4 Connection Persistence
- **ID Recovery**: Ensure agents can resume their previous `HCOM_NAME` and event stream subscription after a crash.
- **Orphan Cleanup**: Conductor must clean up stale entries from the Blackboard for agents that have definitively exited.

## 3. Success Criteria
- [ ] Conductor detects a simulated agent crash and attempts recovery.
- [ ] Latency metrics for remote spokes are visible in the Conductor Dashboard.
- [ ] A rate-limited agent successfully signals its status to the fleet.
- [ ] Stale agent records are automatically pruned from the Blackboard.
