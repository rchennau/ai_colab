# Plan: Git-Aware Conductor & PR Automation

## Phase 1: Branch Management
- [ ] Task: Update `scripts/conductor-workflow.sh` to include git branch creation.
  - [ ] Add `create_track_branch` function.
  - [ ] Integrate with `spawn_workers` loop.
- [ ] Task: Ensure that newly spawned workers (headless agents) are aware of the branch.

## Phase 2: Automated Commits & Validation
- [ ] Task: Update `update_tracks_from_blackboard` to include validation before commit.
  - [ ] If track status is `complete`, run `hcom-test-runner.sh`.
  - [ ] If tests pass, perform `git commit`.
- [ ] Task: Sync the resulting commit SHA to the blackboard and `tracks.md`.

## Phase 3: PR Workflow & Approvals
- [ ] Task: Implement `!approve <slug>` command in the Conductor.
  - [ ] Merges the branch into `main` (if on `main`).
  - [ ] Marks the track as `[x]` in `tracks.md`.
- [ ] Task: Create a blackboard key for "Pseudo-PRs" to track status of pending merges.

## Phase 4: Verification & Testing
- [ ] Task: Create `tests/test_git_lifecycle.sh`.
  - [ ] Mock git environment and verify branch creation and commit logic.
- [ ] Task: Perform a manual test by creating a dummy track and approving it via the console.
