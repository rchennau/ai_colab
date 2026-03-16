# Implementation Plan: Shared Blackboard and Automated Conductor Agent

This plan introduces a shared Key-Value store (Blackboard) for agent coordination and an automated Conductor Agent to manage project lifecycle and track alignment for Atari-LX.

## Phase 1: Shared Blackboard (KV Store)

### 1.1 `hcom kv` CLI Tool
Create a new script `scripts/hcom-kv.sh` (aliased as `hcom-kv`) to provide a standardized interface for agents to interact with the existing `kv` table in `hcom.db`.

**Capabilities:**
- `hcom-kv set <key> <value>`: Store a value.
- `hcom-kv get <key>`: Retrieve a value.
- `hcom-kv list`: List all keys and values.
- `hcom-kv delete <key>`: Remove a key.
- `hcom-kv clear`: Clear the entire blackboard.

### 1.2 Integration with Agent System Prompts
Update the system prompts for `qwen`, `gemini`, `deepseek`, and `claude` to inform them of the `hcom-kv` tool and how to use it for sharing state (e.g., current focus, shared variables, build status).

## Phase 2: Automated Conductor Agent

### 2.1 Conductor Workflow Script
Create `scripts/conductor-workflow.sh` which implements a persistent monitoring loop.

**Logic:**
1. **Startup**: Register as `conductor-agent` with `hcom`.
2. **Subscription**: Subscribe to `plan-sync` and `track-updates` threads.
3. **Monitoring Loop** (every 5-10 minutes):
   - Parse `conductor/tracks.md`.
   - Calculate completion percentages.
   - Detect "Ready" tracks (all dependencies met, status is planning/todo).
   - **Auto-Tasking**: If a track is ready and no agent is assigned, broadcast a request for a worker or suggest spawning one.
   - **Status Pulse**: Broadcast a summary status message to `@all` via `hcom send`.
   - **KV Sync**: Update the blackboard with project health metrics (e.g., `project_progress`, `active_track`).

### 2.2 Dashboard Integration
Update `scripts/dashboard-launch.sh` to optionally include the Conductor Agent:
- Add `--conductor` flag.
- Launch `scripts/conductor-workflow.sh` in a dedicated background pane or as a background process.

## Phase 3: Verification & Testing

### 3.1 Blackboard Test
Create `scripts/test-blackboard.sh`:
- Agent A sets a key.
- Agent B retrieves the key.
- Verify consistency across different agent instances.

### 3.2 Conductor Test
Create `scripts/test-conductor.sh`:
- Modify `conductor/tracks.md` (mock).
- Verify the Conductor Agent detects the change and broadcasts a status update.
- Verify the Blackboard is updated with the new progress metrics.

## Key Files & Context
- `scripts/hcom-kv.sh` (New)
- `scripts/conductor-workflow.sh` (New)
- `scripts/dashboard-launch.sh` (Modified)
- `config.toml` (Modified for launch args)
- `hcom.db` (Storage backend)
