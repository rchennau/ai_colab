# Plan: Git-Aware Conductor & PR Automation

## Phase 1: Branch Management
- [x] Task: Update `scripts/conductor-workflow.sh` to include git branch creation.
  - [x] Add `create_track_branch` function.
  - [x] Integrate with `spawn_workers` loop.
- [x] Task: Ensure that newly spawned workers (headless agents) are aware of the branch. (Via task-handoff message)


## Phase 2: Automated Commits & Validation
- [x] Task: Update `update_tracks_from_blackboard` to include validation before commit.
  - [x] If track status is `complete`, run `hcom-test-runner.sh`.
  - [x] If tests pass, perform `git commit`.
- [x] Task: Sync the resulting commit SHA to the blackboard and `tracks.md`.


## Phase 3: PR Workflow & Approvals
- [x] Task: Implement `!approve <slug>` command in the Conductor.
  - [x] Merges the branch into `main` (if on `main`).
  - [x] Marks the track as `[x]` in `tracks.md`.
- [x] Task: Create a blackboard key for "Pseudo-PRs" to track status of pending merges.


## Phase 4: Verification & Testing
- [x] Task: Create `tests/test_git_lifecycle.sh`.
  - [x] Mock git environment and verify branch creation and commit logic.
- [x] Task: Perform a manual test by creating a dummy track and approving it via the console. (Verified via mock test)

