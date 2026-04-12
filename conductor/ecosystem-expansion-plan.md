# Ecosystem Expansion (Phase 19) Implementation Plan

## Background & Motivation
`ai-colab` currently relies on local installations of LLM CLIs (Gemini, Claude, Qwen) and system-level dependencies. While the Portable Python runtime via `uv` mitigates some environment issues, a fully scalable orchestration platform requires absolute isolation for each agent. By containerizing agents (Phase 19.1), the Conductor can orchestrate fleets across a distributed swarm, ensuring identical runtime environments, resource constraints, and security sandboxing regardless of the host machine. This lays the groundwork for Cloud Deployments (P19.2), Module Marketplaces (P19.4), and IDE Integration (P19.3).

## Phase 19.1: Containerized Agents (P4.1)

### 1. Docker Architecture & Base Images
Develop specialized Dockerfiles for each supported agent within `docker/agents/`.
*   **Base Image (`docker/agents/base/Dockerfile`)**: An Alpine or minimal Ubuntu image equipped with `hcom`, `python3`, `uv`, `git`, and the shared MCP client utilities.
*   **Agent Images (`docker/agents/{gemini,claude,qwen}/Dockerfile`)**: Extending the base image to install specific LLM CLI packages (e.g., `gemini-cli`, `@anthropic-ai/claude-code`, `qwen-agent`).
*   **Volumes & Networking**: Agents must be provided access to the target project directory (`/workspace`), the `hcom` configuration (`~/.hcom`), and the shared blackboard database to maintain state.

### 2. Integration with `agent-wrapper.sh`
Modify the core execution loop in `scripts/agent-wrapper.sh` to support a containerized execution context.
*   Add a `--docker` or container-mode flag.
*   Instead of `eval "$CMD"`, use `docker run --rm -d -v "$PROJECT_ROOT:/workspace" -v "$HOME/.hcom:/root/.hcom" --name "agent_${HCOM_NAME}" aicolab/agent-$TOOL ...`.
*   The wrapper remains responsible for parsing output (via `docker logs -f`), monitoring container health, and triggering circuit breaker logic if the container crashes or fails to start.

### 3. Conductor Spawning Logic
Update `scripts/conductor-workflow.sh`'s `spawn_workers` function.
*   Instead of spawning local tmux panes or background processes, check if Docker is available and `CONTAINER_MODE` is enabled.
*   If enabled, spawn the containerized versions of the highest-rated agents.

### 4. QA & Validation
*   **Unit Tests (`tests/test_container_agents.sh`)**: Verify that the generated `docker run` commands contain the correct volume mounts, environment variables, and network settings.
*   **Integration Tests**: Ensure a containerized Gemini agent can receive a task via `hcom`, modify a file in `/workspace`, and correctly report progress to the Blackboard.

## Timeline & Deliverables
- **Step 1**: Design and build the Base and Gemini Dockerfiles.
- **Step 2**: Refactor `agent-wrapper.sh` to support Docker execution.
- **Step 3**: Update the Conductor's worker spawning logic.
- **Step 4**: Develop and execute the integration test harness.
