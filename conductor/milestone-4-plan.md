# Milestone 4: Multi-Project & Advanced Orchestration

## Objective
To extend the Conductor Agent's capabilities to manage multiple projects, sub-tracks, and advanced git-based coordination.

## Proposed Changes

### 1. Multi-Project Support
- Allow the Conductor Agent to switch between different project roots or track files via `hcom` commands.
- Key: `!switch <project_path>`.
- Blackboard Key: `conductor_current_project`.

### 2. Advanced Build & Sync
- Implement `!build` command to trigger the local project's build system (e.g., `make`).
- Implement `!git-sync` to pull latest changes and report merge status to the team.

### 3. Track Dependency Resolution
- Add support for "Track Dependencies" in `tracks.md` (e.g., `[ ] **Track: Feature B** (Requires: Feature A)`).
- Conductor should only spawn workers for tracks whose dependencies are met.

## Verification
- Create test project and tracks.
- Verify `!switch` command correctly updates the monitoring loop.
- Verify dependency resolution prevents premature tasking.
