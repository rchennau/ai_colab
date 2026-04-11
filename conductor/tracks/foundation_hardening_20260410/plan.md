# Implementation Plan: Foundation Hardening (Phase 16)

## Execution Order

Tasks are ordered by dependency and impact:

```
P16.1 (Message Queue) ──→ P16.2 (Event Cursor)
                              ↓
P16.3 (Schema Validation) ──→ P16.4 (Agent Selection) ──→ P16.5 (Agent Recovery)
                                                              ↓
P16.6 (MQTT Security) ──────────────────────────────────────┘
```

## Phase 16.1: Message Queue Layer

### Step 1: Create `scripts/message-queue.sh`
- SQLite-based message queue
- Functions: `mq_init()`, `mq_send()`, `mq_deliver()`, `mq_ack()`, `mq_retry()`, `mq_dead_letter()`, `mq_status()`
- Schema: messages table with status tracking
- TTL enforcement on delivery attempt

### Step 2: Integrate with `scripts/utils.sh`
- Add `mq_send()` wrapper that falls back to `hcom send` if MQ unavailable
- Add `mq_check_pending()` for delivery loop

### Step 3: Modify `scripts/conductor-workflow.sh`
- Replace `hcom send` calls with `mq_send`
- Add delivery loop in main conductor cycle

### Step 4: Create `tests/test_message_queue.sh`
- Test: send to offline agent → verify queued
- Test: agent comes online → verify delivered
- Test: retry logic (3 attempts)
- Test: dead-letter queue after max retries
- Test: TTL expiration

---

## Phase 16.2: Event Processing Resilience

### Step 1: Modify `scripts/conductor-workflow.sh`
- Replace `hcom events --sql "id > $LAST"` with cursor-based system
- Read cursor from blackboard on startup
- Store cursor to blackboard every loop iteration
- Implement deduplication window (last 100 event IDs)

### Step 2: Create `tests/test_event_cursor.sh`
- Test: crash simulation → restart → verify no events missed
- Test: duplicate event detection
- Test: cursor persistence across restarts

---

## Phase 16.3: Blackboard Schema Validation

### Step 1: Create `config/blackboard-schema.json`
- Define key namespaces: `project_*`, `track_*`, `agent_*`, `test_*`, `hook_*`, `recovery_*`, `mq_*`
- Define value types and constraints
- Define reserved namespaces: `conductor_*`, `system_*`

### Step 2: Modify `scripts/hcom-kv.sh`
- Add `kv_set_validated()` — validates against schema before write
- Add `kv_cleanup_expired()` — removes expired TTL keys
- Add `kv_atomic_set()` — multi-key set via SQLite transaction

### Step 3: Create `tests/test_blackboard_schema.sh`
- Test: invalid write rejected
- Test: TTL cleanup
- Test: atomic multi-key set
- Test: reserved namespace protection

---

## Phase 16.4: Intelligent Agent Selection

### Step 1: Create `config/agent-capabilities.json`
```json
{
  "gemini": {"reasoning": 0.9, "coding": 0.7, "architecture": 0.9, "documentation": 0.8, "optimization": 0.6, "review": 0.7},
  "qwen": {"reasoning": 0.7, "coding": 0.9, "architecture": 0.6, "documentation": 0.5, "optimization": 0.8, "review": 0.7},
  "claude": {"reasoning": 0.8, "coding": 0.8, "architecture": 0.7, "documentation": 0.9, "optimization": 0.6, "review": 0.8},
  "deepseek": {"reasoning": 0.8, "coding": 0.8, "architecture": 0.6, "documentation": 0.5, "optimization": 0.9, "review": 0.7},
  "nemoclaw": {"reasoning": 0.8, "coding": 0.6, "architecture": 0.9, "documentation": 0.5, "optimization": 0.7, "review": 0.6}
}
```

### Step 2: Modify `scripts/conductor-workflow.sh`
- Add `analyze_task_requirements()` — parse track description for keywords
- Add `select_best_agent()` — match requirements to capabilities
- Modify `spawn_workers()` to use intelligent selection

### Step 3: Create `tests/test_agent_selection.sh`
- Test: code-heavy task → Qwen/Claude selected
- Test: architecture task → Gemini/nemoclaw selected
- Test: optimal agent down → fallback to next-best
- Test: all agents down → no spawn (graceful failure)

---

## Phase 16.5: Agent Recovery Improvements

### Step 1: Modify `scripts/agent-wrapper.sh`
- Replace count-based restart with exponential backoff
- Track restart timestamps in temp file
- Implement circuit breaker logic

### Step 2: Modify `scripts/conductor-workflow.sh`
- Add circuit breaker state tracking in blackboard
- Implement task rerouting for unhealthy agents
- Add `check_circuit_breaker()` function

### Step 3: Create `tests/test_agent_recovery.sh`
- Test: exponential backoff timing
- Test: circuit breaker opens after 5 failures
- Test: task rerouting when agent unhealthy
- Test: circuit breaker closes after successful test

---

## Phase 16.6: MQTT Security

### Step 1: Modify `docker-compose.yml`
- Add Mosquitto service with `mqtt` profile
- Configure TLS and authentication
- Volume mount for config and data persistence

### Step 2: Modify `config.toml`
- Update relay section with secure defaults
- Add TLS and auth configuration options

### Step 3: Create `docs/mqtt-setup.md`
- Deployment instructions
- TLS certificate generation
- Authentication setup
- Troubleshooting guide

---

## Development Workflow

Each task follows the standard workflow:

1. **Create track branch:** `git checkout -b track/foundation-hardening-p16`
2. **Write tests first** (TDD)
3. **Implement feature**
4. **Run tests** — must pass
5. **Commit** — conventional commit message
6. **Update this plan** — mark task complete
7. **Conductor approval** — via `!approve` command

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Message queue adds latency | Keep SQLite in-memory mode for hot path, flush to disk periodically |
| Schema validation breaks existing agents | Graceful fallback: if schema unavailable, allow all writes with warning |
| Agent selection algorithm too slow | Pre-compute capability scores, cache in memory |
| Circuit breaker too aggressive | Configurable thresholds, manual override via `!reset-circuit` |
| MQTT migration breaks existing setup | Dual-mode: support both public and self-hosted brokers during transition |
