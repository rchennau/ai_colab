# Track: Performance Trending & Dashboard (v3.0)

## 1. Objective
Enable historical tracking of routine performance and provide a high-density "Project Health" TUI for the Conductor.

## 2. Specification

### 2.1 Performance History (Persistence)
- Update `scripts/hcom-profiler.sh` to store data in a persistent format (SQLite table or CSV).
- Track: `timestamp`, `routine_name`, `cycle_count`, `commit_sha`.
- Command: `!perf-trend <routine_name>` - Generates a textual trend report (improving/regressing).

### 2.2 Conductor Dashboard (v3.0)
- Enhance the Conductor's monitoring loop to maintain a "Project Summary" on the screen.
- Instead of just scrolling logs, the terminal should be cleared and updated with:
  - **Project Header** (Name, Version)
  - **Milestone Progress** (Overall percentage)
  - **Active Task** (Current track + assigned worker)
  - **Performance Summary** (Latest cycle counts for 3 most recent routines)
  - **Memory Summary** (Top 3 segments + usage %)
  - **Recent Events** (Last 3 hcom messages)

### 2.3 Integrated Alerts
- Trigger an `hcom` alert if a routine's performance regresses by more than 5% compared to the previous commit.

## 3. Implementation Details
- **TUI Framework**: Use the `rich` (Python) or a similar Bash-based approach for clean formatting.
- **Persistence**: Store data in a new `performance` table in `hcom.db`.

## 4. Success Criteria
- [ ] Conductor terminal shows a high-density "Project Summary".
- [ ] Historical performance data is stored and retrievable.
- [ ] `!perf-trend` command shows improvements or regressions.
- [ ] Automatic alerts for performance regressions.
