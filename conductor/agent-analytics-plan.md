# Agent Analytics Web UI Integration Implementation Plan

## Background & Motivation
The `ai-colab` orchestration core actively logs agent performance metrics (including session duration, success vs. crash status, and exit codes) to the SQLite blackboard via the `log_agent_analytics()` function. However, this valuable data is currently locked in the database. To provide engineering managers with visibility into fleet health, efficiency, and cost-effectiveness, we need to surface these metrics in the Web UI.

## Phase 1: Backend API Development
1. **New Blueprint (`webui/api/agents.py`)**:
   * Create a new Flask blueprint for agent-related data.
   * Implement `GET /api/agents/analytics` to query the `agent_analytics` SQLite table.
   * Calculate aggregations per agent: 
     * Total sessions/executions
     * Success rate (%)
     * Average (mean/median) duration per task
     * Total crashes/errors
2. **App Registration**:
   * Register the new blueprint in `webui/app_refactored.py`.

## Phase 2: Frontend Visualization
1. **Web UI Updates (`webui/index.html`)**:
   * Add a new "Analytics" section or tab within the "System" view.
   * Fetch data from `/api/agents/analytics` on load/refresh.
   * Display the data using a clear, sortable table or lightweight visual bar charts (using standard HTML/CSS or Chart.js via CDN).
   * Include color-coding for success rates (e.g., green for >90%, red for <50%).

## Phase 3: QA & Testing
1. **Automated Tests (`tests/test_webui.sh`)**:
   * Add a test case to ensure the `/api/agents/analytics` endpoint returns a valid JSON HTTP 200 response.
   * Verify the JSON structure includes the expected aggregation keys (`agent_name`, `success_rate`, `avg_duration`).

## Timeline
- **Step 1**: Develop and test the `/api/agents/analytics` backend endpoint.
- **Step 2**: Build the frontend UI components and wire them to the API.
- **Step 3**: Write automated tests and verify end-to-end functionality.
