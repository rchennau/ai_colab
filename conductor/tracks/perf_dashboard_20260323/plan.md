# Plan: Performance Trending & Dashboard (v3.0)

## Phase 1: Performance Persistence
- [ ] Task: Update `hcom.db` schema to include a `performance` table.
- [ ] Task: Update `scripts/hcom-profiler.sh` to insert results into the new table.
- [ ] Task: Implement cycle count comparison logic (current vs. previous).

## Phase 2: Trending CLI Tool
- [ ] Task: Create `scripts/hcom-perf-trend.sh`.
- [ ] Task: Implement trend analysis logic (calculate % change).
- [ ] Task: Add the `!perf-trend` command to the Conductor.

## Phase 3: Dashboard v3.0 (Project Summary)
- [ ] Task: Create `scripts/conductor-dashboard.py` (High-density TUI).
- [ ] Task: Implement live data binding (Milestones, Tracks, Performance).
- [ ] Task: Update `scripts/conductor-workflow.sh` to use the dashboard script for its main terminal output.

## Phase 4: Verification & Testing
- [ ] Task: Create `tests/test_performance_trending.sh`.
- [ ] Task: Verify that regressions trigger an `hcom` alert.
- [ ] Task: Perform a manual visual test of the new dashboard UI.
