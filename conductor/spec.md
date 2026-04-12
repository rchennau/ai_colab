# Track Specification: Agent Analytics Web UI Integration

## Overview
While the orchestration core currently logs agent performance metrics (session duration, success rates, exit codes) to the SQLite blackboard via `log_agent_analytics()`, this data remains inaccessible to users. This track bridges that gap by creating a dedicated Web UI dashboard to visualize agent performance, providing engineering managers with critical insights into fleet efficiency.

## Goals
1.  **API Data Exposure**: Create a new API endpoint to query and aggregate historical agent analytics from the Blackboard.
2.  **Performance Visualization**: Develop a new section or dedicated sub-page in the Web UI to display key metrics (Avg Session Time, Crash Rate, Activity Distribution).
3.  **Intelligent Insights**: Provide actionable data to help users determine if specific agents (e.g., Claude vs. Gemini) are underperforming on certain task types.

## Requirements
- **Backend (`webui/api/agents.py`)**: 
  - Read from the `agent_analytics` SQLite table.
  - Calculate aggregations (e.g., total executions, success rate, median duration per agent).
- **Frontend (`webui/index.html`)**:
  - Add a new "Analytics" tab or section within the "System" menu.
  - Use simple HTML/CSS bar charts or a lightweight charting library (e.g., Chart.js via CDN) to render the data.
- **Testing**:
  - Add automated tests to `tests/test_webui.sh` to verify the new endpoint returns valid JSON data.

## Success Criteria
- [ ] The `/api/agents/analytics` endpoint successfully returns aggregated performance data.
- [ ] The Web UI displays a table or chart comparing the success rates and average durations of all active agents.
- [ ] The UI gracefully handles empty states (e.g., when no analytics data exists yet).
