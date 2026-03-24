# Plan: Performance Trending & Dashboard (v3.0)

## Phase 1: Performance Persistence
- [x] Task: Update `hcom.db` schema to include a `performance` table.
- [x] Task: Update `scripts/hcom-profiler.sh` to insert results into the new table.
- [x] Task: Implement cycle count comparison logic (current vs. previous).

## Phase 2: Trending CLI Tool
- [x] Task: Create `scripts/hcom-perf-trend.sh`.
- [x] Task: Implement trend analysis logic (calculate % change).
- [x] Task: Add the `!perf-trend` command to the Conductor.

## Phase 3: Dashboard v3.0 (Project Summary)
- [x] Task: Create `scripts/conductor-dashboard.sh` (High-density TUI).
- [x] Task: Implement live data binding (Milestones, Tracks, Performance).
- [x] Task: Update `scripts/conductor-workflow.sh` to use the dashboard script for its main terminal output.

## Phase 4: Verification & Testing
- [x] Task: Create `tests/test_performance_trending.sh`.
- [x] Task: Verify that regressions trigger an `hcom` alert.
- [x] Task: Perform a manual visual test of the new dashboard UI.

