# Implementation Plan: Automated Conductor Tasking

This plan enhances the Conductor Agent to actively manage agent spawning and task assignment based on the project state defined in `conductor/tracks.md`.

## 1. Objectives
- Automatically detect "Ready" tracks (status `[ ]` in `tracks.md`).
- Ensure each ready track has an assigned agent.
- Spawn new agents (headless workers) when necessary.
- Coordinate initial task handoff via `hcom` messaging.
- Maintain assignment state in the Shared Blackboard (`hcom-kv`).

## 2. Implementation Steps

### 2.1 Enhance `scripts/conductor-workflow.sh`
- **Assignment Logic**:
  - For each `[ ]` track found in `tracks.md`:
    - Check the Blackboard for `track_assigned_<track_slug>`.
    - If missing or the assigned agent is dead (via `hcom list`), mark as "Unassigned".
- **Spawn Logic**:
  - If a track is "Unassigned":
    - Determine model (default: `gemini` for coding tasks).
    - Execute: `hcom 1 gemini --tag worker --headless --go`.
    - Parse the resulting agent name (e.g., `luna`).
    - Update Blackboard: `track_assigned_<track_slug> = <agent_name>`.
    - Update Blackboard: `agent_task_<agent_name> = <track_name>`.
- **Handoff Logic**:
  - `hcom send @<agent_name> --intent request --thread "task-handoff" -- "Your task is to implement the following track: <track_name>. Please review conductor/tracks.md and report progress via the blackboard."`.

### 2.2 Shared Blackboard Updates
- Define keys:
  - `track_assigned_<track_slug>`: Name of the agent working on the track.
  - `agent_task_<agent_name>`: The track description assigned to the agent.
  - `conductor_max_workers`: Configurable limit for simultaneous workers (default: 1).

### 2.3 Verification & Testing

#### 3.1 Auto-Tasking Test
Create `scripts/test-auto-tasking.sh`:
1. Start the Conductor Agent in a background process.
2. Update `conductor/tracks.md` with a new `[ ]` track.
3. Wait and verify:
   - A new agent appears in `hcom list`.
   - The Blackboard reflects the assignment.
   - An `hcom` event shows the task handoff message.
4. Clean up mock agents.

## 4. Key Files
- `scripts/conductor-workflow.sh` (Modified)
- `scripts/test-auto-tasking.sh` (New)
- `conductor/tracks.md` (Observed)
