# Track blackboard_tasking_20260322: Specification

## Goal
Transition the Conductor's task management from a file-only approach to a blackboard-driven system using `hcom-kv`. This enables real-time task handoffs, automated progress tracking, and better visibility across multiple agents.

## Key Requirements

1. **Blackboard Integration:**
   - Utilize `hcom-kv` to store the current active task, status, and progress.
   - Standardize the keys for task management (e.g., `active_task`, `active_task_status`, `active_task_progress`).

2. **Automated Sync:**
   - Implement logic in `scripts/conductor-workflow.sh` to synchronize the blackboard state with `conductor/tracks.md`.
   - Update `tracks.md` status automatically when an agent marks a task as complete on the blackboard.

3. **Real-time Visibility:**
   - Ensure the Dashboard accurately reflects the blackboard's state.
   - Provide visual feedback for task transitions (e.g., "PENDING" to "IN PROGRESS").

4. **Multi-Agent Coordination:**
   - Allow agents to "claim" tasks from the blackboard.
   - Implement a conflict-resolution mechanism if multiple agents attempt to claim the same task.

## Acceptance Criteria
- [ ] Conductor scripts can read/write task status to the blackboard via `hcom-kv`.
- [ ] `conductor/tracks.md` is updated automatically within 30 seconds of a blackboard change.
- [ ] The Dashboard TUI displays the current active task and overall project progress.
- [ ] At least two agents (e.g., Gemini and Qwen) can successfully hand off a task via the blackboard.
