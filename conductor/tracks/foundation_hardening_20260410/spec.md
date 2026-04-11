# Track: Foundation Hardening (Phase 16)

**ID:** `foundation_hardening_20260410`  
**Created:** 2026-04-10  
**Status:** In Progress 🔄  
**Assigned:** @conductor, @architect  
**Priority:** Critical  

---

## Overview

Phase 16 focuses on making the ai-colab orchestration core production-reliable. The current system works but has critical reliability gaps: lost messages, fragile event processing, blackboard race conditions, and dumb agent selection. This phase addresses all of them.

**Theme:** "Make it unbreakable"

---

## Tasks

### P16.1: Message Queue Layer (P1.1)

**Problem:** hcom has no message acknowledgment. If an agent is offline when a message is sent, it's lost forever. Task assignments silently fail.

**Solution:** Implement a lightweight SQLite-based message queue with:
- Message persistence (stored until acknowledged)
- Queue for offline agents (delivered on reconnection)
- Retry logic with configurable max attempts (default: 3)
- Message TTL (default: 24h) and dead-letter queue
- Acknowledgment via blackboard (`mq_ack_<message_id>`)

**Files to create/modify:**
- `scripts/message-queue.sh` — Core MQ functions
- `scripts/utils.sh` — Add `mq_send()`, `mq_ack()`, `mq_pending()`, `mq_retry()`
- `scripts/conductor-workflow.sh` — Use `mq_send()` instead of direct `hcom send`
- `tests/test_message_queue.sh` — Test suite

**Acceptance Criteria:**
- [ ] Messages to offline agents are queued
- [ ] Queued messages delivered within 5s of agent reconnection
- [ ] Failed messages retried 3 times with exponential backoff
- [ ] Dead-letter queue accessible for inspection
- [ ] Zero message loss in 7-day stress test

---

### P16.2: Event Processing Resilience (P1.2)

**Problem:** Conductor uses `hcom events --all --sql "id > $LAST_EVENT_ID"` — if conductor crashes and restarts, it may miss events between the last processed ID and the new start.

**Solution:** Cursor-based event processing:
- Persist last-processed event ID to blackboard (`conductor_event_cursor`)
- On startup, read cursor from blackboard
- Deduplication: maintain a small window of processed event IDs
- Heartbeat the cursor every loop iteration

**Files to modify:**
- `scripts/conductor-workflow.sh` — Replace event processing logic
- `scripts/hcom-kv.sh` — Add cursor-specific functions

**Acceptance Criteria:**
- [ ] Conductor resumes from persisted cursor after restart
- [ ] No events missed between crash and restart
- [ ] No events double-processed (deduplication verified)
- [ ] Cursor persists to blackboard every 60s

---

### P16.3: Blackboard Schema Validation (P1.3)

**Problem:** Flat KV store with no schema validation, no TTL enforcement, no atomic multi-key operations. Race conditions under concurrent writes.

**Solution:**
- JSON schema for blackboard key namespaces
- TTL enforcement (cleanup expired keys on read/write)
- Atomic multi-key operations via SQLite transactions
- Reserved namespace protection (prevent writes to `conductor_*`, `system_*`)

**Files to modify:**
- `scripts/hcom-kv.sh` — Add validation layer
- `scripts/utils.sh` — Add `blackboard_set_validated()`, `blackboard_atomic_set()`
- `config/blackboard-schema.json` — Schema definition

**Acceptance Criteria:**
- [ ] Invalid writes rejected with error message
- [ ] Expired keys cleaned up on next read/write
- [ ] Atomic multi-key sets succeed or fail together
- [ ] Reserved namespaces protected from agent writes

---

### P16.4: Intelligent Agent Selection (P1.4)

**Problem:** `spawn_workers()` only spawns Gemini agents regardless of task complexity. No capability-based routing.

**Solution:** Capability registry and task matching:
- Define capability schema: `reasoning`, `coding`, `architecture`, `documentation`, `optimization`, `review`
- Register agent capabilities in blackboard (`agent_caps_<name>`)
- Analyze track requirements (keywords, file patterns)
- Select best-matching available agent
- Fallback to available agent if optimal is down

**Files to modify:**
- `scripts/conductor-workflow.sh` — Agent selection logic
- `scripts/utils.sh` — Add `agent_get_caps()`, `agent_match_task()`
- `config/agent-capabilities.json` — Default capability definitions

**Acceptance Criteria:**
- [ ] Each registered agent has capability profile
- [ ] Tasks routed to best-matching available agent
- [ ] Fallback to next-best agent if optimal unavailable
- [ ] Capability profiles configurable via JSON

---

### P16.5: Agent Recovery Improvements (P1.5)

**Problem:** Simple count-based restart (max 10). No exponential backoff, no circuit breaker, no root cause analysis.

**Solution:**
- Exponential backoff: 10s → 30s → 60s → 120s (cap at 120s)
- Circuit breaker: after 5 failures in 10 min, mark "unhealthy"
- Auto-reroute tasks from unhealthy agents
- Recovery attempt tracking in blackboard

**Files to modify:**
- `scripts/agent-wrapper.sh` — Restart logic with backoff
- `scripts/conductor-workflow.sh` — Circuit breaker logic
- `scripts/utils.sh` — Add `agent_mark_unhealthy()`, `agent_is_healthy()`

**Acceptance Criteria:**
- [ ] Restart delays follow exponential backoff
- [ ] Agent marked "unhealthy" after 5 failures in 10 min
- [ ] Tasks re-routed from unhealthy agents automatically
- [ ] Recovery attempts tracked and queryable

---

### P16.6: MQTT Security Hardening (P1.6)

**Problem:** Public MQTT broker (emqx.io) with no authentication. Token is empty in config.

**Solution:**
- Self-hosted Mosquitto or EMQX broker
- TLS encryption
- Username/password authentication
- Documented deployment via Docker Compose profile: `mqtt`

**Files to modify:**
- `config.toml` — Secure defaults
- `docker-compose.yml` — Add MQTT service with profile
- `docs/mqtt-setup.md` — Deployment guide

**Acceptance Criteria:**
- [ ] Self-hosted MQTT broker deploys via Docker Compose
- [ ] TLS encryption enabled
- [ ] Authentication required for connections
- [ ] Documentation covers setup and troubleshooting

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P16.1 (Message Queue) | None |
| P16.2 (Event Cursor) | P16.1 (uses MQ for cursor persistence) |
| P16.3 (Schema Validation) | None |
| P16.4 (Agent Selection) | None |
| P16.5 (Agent Recovery) | P16.4 (needs capability registry for failover) |
| P16.6 (MQTT Security) | None |

**Recommended order:** P16.1 → P16.3 → P16.4 → P16.2 → P16.5 → P16.6

---

## Testing Strategy

Each task includes its own test suite:

| Task | Test File | Test Type |
|------|-----------|-----------|
| P16.1 | `tests/test_message_queue.sh` | Shell (offline agent simulation, delivery verification, retry logic) |
| P16.2 | `tests/test_event_cursor.sh` | Shell (crash simulation, cursor persistence, deduplication) |
| P16.3 | `tests/test_blackboard_schema.sh` | Shell (invalid writes, TTL cleanup, atomic operations) |
| P16.4 | `tests/test_agent_selection.sh` | Shell (capability matching, fallback routing) |
| P16.5 | `tests/test_agent_recovery.sh` | Shell (backoff timing, circuit breaker, task rerouting) |
| P16.6 | `tests/test_mqtt_security.sh` | Shell (TLS verification, auth requirement) |

All tests integrated into `scripts/test-all.sh` and CI/CD pipeline.

---

## Success Metrics

| Metric | Before | Target | Measurement |
|--------|--------|--------|-------------|
| Message loss rate | Unknown (no tracking) | 0% | MQ delivery tracking |
| Event processing gaps | Possible on restart | 0% | Cursor verification |
| Blackboard race conditions | Possible | Eliminated | Schema validation + atomic ops |
| Agent-task match quality | 100% Gemini | ≥ 70% optimal | Post-hoc evaluation |
| Mean time to recovery | 10s (fixed) | ≤ 120s (with backoff) | Recovery attempt tracking |
| MQTT security | None (public broker) | TLS + auth | Security audit |

---

## Implementation Notes

### Message Queue Design

The message queue is intentionally lightweight — no Redis, no external dependencies. It uses SQLite (already available via hcom.db or a separate `mq.db`) with this schema:

```sql
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    target TEXT NOT NULL,
    sender TEXT NOT NULL,
    content TEXT NOT NULL,
    intent TEXT DEFAULT 'inform',
    thread TEXT DEFAULT 'default',
    status TEXT DEFAULT 'pending',  -- pending, delivered, acked, failed, dead_letter
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,
    acked_at TIMESTAMP,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    ttl_seconds INTEGER DEFAULT 86400,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_messages_status ON messages(status, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_target ON messages(target, status);
```

### Circuit Breaker Design

```
States: CLOSED → OPEN → HALF_OPEN → CLOSED

CLOSED:     Agent is healthy. Normal operation.
            → Transition to OPEN after 5 failures in 10 min.

OPEN:       Agent is unhealthy. No tasks routed here.
            → Transition to HALF_OPEN after 5 min cooldown.

HALF_OPEN:  Test agent with a simple task.
            → If succeeds: CLOSED
            → If fails: OPEN (reset cooldown)
```

### Capability Schema

```json
{
  "agent_caps_<name>": {
    "reasoning": 0.9,
    "coding": 0.7,
    "architecture": 0.8,
    "documentation": 0.6,
    "optimization": 0.5,
    "review": 0.7
  }
}
```

Scores are 0.0-1.0, representing relative strength in each area. Default values defined in `config/agent-capabilities.json`, overridden by actual performance metrics over time.
