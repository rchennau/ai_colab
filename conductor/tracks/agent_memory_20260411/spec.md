# Track: Agent Memory & Persistent Context (P5.2)

**ID:** `agent_memory_20260411`  
**Created:** 2026-04-11  
**Status:** In Progress 🔄  
**Assigned:** @conductor, @architect  
**Priority:** High  

---

## Overview

Agents currently lose all conversation context when they restart. P5.2 implements persistent conversation history stored in the blackboard, with configurable context window management and memory compression for long-running agents.

**Theme:** "Remember to be effective"

---

## Tasks

### P5.2.1: Conversation History Storage

Store agent conversation history in SQLite blackboard:
- Each agent has its own memory namespace (`agent_memory_<name>`)
- Messages stored with timestamps, role (user/assistant/system), and content
- Configurable max history size per agent

**Files:** `scripts/memory-manager.py`

### P5.2.2: Context Window Management

Manage what context is injected into agent prompts:
- Configurable max context window (e.g., last 100 messages or 50KB)
- Sliding window: oldest messages dropped when window exceeded
- Priority system: system messages and recent messages always included

**Files:** `scripts/memory-manager.py`, `config/memory-config.json`

### P5.2.3: Memory Compression

Compress long conversation history for efficient storage:
- Summarize old conversations using LLM
- Store summaries alongside raw messages
- Replace old messages with summaries when compressing
- Configurable compression threshold (e.g., compress after 200 messages)

**Files:** `scripts/memory-compressor.py`

### P5.2.4: Agent Wrapper Integration

Integrate memory into agent lifecycle:
- On agent start: load recent conversation context
- On agent stop: save final conversation state
- Periodic save: save conversation every N messages or M minutes

**Files:** `scripts/agent-wrapper.sh`, `scripts/agent-memory.sh`

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P5.2.1 (Storage) | None |
| P5.2.2 (Context Window) | P5.2.1 |
| P5.2.3 (Compression) | P5.2.2 |
| P5.2.4 (Integration) | P5.2.2 |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Context persistence | 100% of conversations survive restart | Blackboard storage verification |
| Context injection | < 100ms to load context on agent start | Startup timing measurement |
| Memory compression | < 10s to compress 200 messages | Compression timing |
| Storage efficiency | < 1MB per agent per day of conversation | Blackboard size monitoring |
