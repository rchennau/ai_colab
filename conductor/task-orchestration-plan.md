# Task Orchestration Intelligence (Phase 18) Implementation Plan

## Background & Motivation
The Conductor currently assigns tasks to agents in a 1-to-1 manner and waits for completion. To achieve true autonomy, agents must collaborate on complex tasks using formal patterns (e.g., a "Coder" agent writes code, a "Reviewer" agent checks it). Furthermore, the Conductor needs a structured way to monitor progress and enforce quality standards before marking a track as complete.

## Phase 18.2: Multi-Agent Collaboration Patterns (P3.2)
1. **Workflow Engine Update**:
   * Refactor `scripts/conductor-workflow.sh` to support multi-step assignments.
   * Implement the **Review Pattern**: When a track is assigned, the Conductor selects an implementer (e.g., Qwen) and a reviewer (e.g., Claude).
   * The Conductor sends the task to the implementer. Upon completion, it automatically routes the PR/diff to the reviewer.
   * If the reviewer rejects, it routes back to the implementer with feedback.

## Phase 18.3: Structured Progress Tracking (P3.3)
1. **Progress Protocol**:
   * Define a JSON schema for agent progress reports: `{"progress": Int, "step": String, "blockers": [String]}`.
   * Update `scripts/agent-wrapper.sh` to parse specific stdout patterns (e.g., `PROGRESS: 50% | Implementing X`) and broadcast them via `hcom`.
2. **Dashboard Integration**:
   * Update `scripts/conductor-dashboard.sh` to display the real-time progress and current step of each active agent.

## Phase 18.4: Automated Quality Gates (P3.4)
1. **Quality Gate Script**:
   * Create `scripts/quality-gates.sh` to execute a configurable suite of validation checks (e.g., `pytest`, `flake8`, `bandit`).
   * The Conductor runs this script before marking a track as "Done".
   * If the script fails, the Conductor routes the failure output back to the implementer agent as a new task to fix the errors.

## Phase 18.5: Agent Analytics (P3.5)
1. **Analytics Logging**:
   * Update `scripts/utils.sh` to log agent performance metrics (start time, end time, success/failure, tokens used if available) to a dedicated SQLite table (`agent_analytics`) in the blackboard database.
2. **Analytics Retrieval**:
   * Create a new endpoint in `webui/api/agents.py` to expose these metrics for visualization in the WebUI.

## Timeline
- **Phase 18.2**: Implement collaboration patterns in `conductor-workflow.sh`.
- **Phase 18.3**: Standardize progress reporting in `agent-wrapper.sh` and the dashboard.
- **Phase 18.4**: Develop `quality-gates.sh` and integrate it into the Conductor's merge workflow.
- **Phase 18.5**: Implement analytics logging and the WebUI endpoint.
