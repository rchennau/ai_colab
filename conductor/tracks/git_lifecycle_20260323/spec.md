# Track: Git-Aware Conductor & PR Automation

## 1. Objective
Enhance the Conductor agent to automatically manage the git lifecycle for project tracks, ensuring that each task is developed in an isolated branch and that progress is committed upon successful validation.

## 2. Specification

### 2.1 Automated Branch Creation
- When the Conductor spawns a worker for a track (status `[ ]`), it should:
  1. Create a git branch named `track/<track_slug>`.
  2. Switch the project root to this branch (or ensure the worker operates in it).
- **Format**: `track/automated-qa-20260323`

### 2.2 Progress Commits
- When a worker reports a track as "complete" via the Blackboard (`track_status_<slug> = complete`), the Conductor should:
  1. Verify the changes (run `hcom-test-runner.sh`).
  2. If tests pass:
     - Run `git add .` and `git commit -m "Auto-commit: Completed track <track_name>"`.
     - Update the blackboard with the resulting commit SHA.

### 2.3 Pseudo-PR Management
- Instead of just marking the track as `[x]` in `tracks.md`, the Conductor should:
  1. Create a blackboard key `pr_<track_slug>` containing a summary of changes.
  2. Broadcast a "Pull Request Ready" message to `@all`.
  3. Wait for manual approval or an `!approve <slug>` command before merging (or marking as complete).

### 2.4 Blackboard Keys
- `track_branch_<track_slug>`: The git branch assigned to the track.
- `pr_<track_slug>`: Status and description of the pending merge.
- `last_merged_track`: The name of the most recently merged track.

## 3. Success Criteria
- [ ] Conductor creates a branch when spawning a worker.
- [ ] Conductor commits changes after a successful test run.
- [ ] Conductor handles the `!approve` command to finalize a track.
- [ ] Changes are eventually merged back to `main`.
