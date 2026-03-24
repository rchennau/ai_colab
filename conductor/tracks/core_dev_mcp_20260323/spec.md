# Track: MCP-First Architecture (Core Dev)

## 1. Objective
Formalize the multi-agent development workflow by replacing large system prompts with a specialized **Model Context Protocol (MCP)** server. This allows agents to interact with the project infrastructure through well-defined tools rather than textual instructions.

## 2. Specification

### 2.1 Core Dev MCP Server
Create a Python-based MCP server located in `mcp/core-dev/`.

### 2.2 Tools
- `request_task_handoff(target_agent, context)`: Sends a formalized message to another agent with a reference to the current task.
- `propose_milestone(title, description, tasks)`: Generates a new milestone/track entry for `tracks.md`.
- `verify_style_compliance(file_path)`: Triggers the automated code reviewer for a specific file.
- `get_project_summary()`: Returns a structured summary of the current project state (extracted from Blackboard).

### 2.3 Deployment
- Integrate the `core-dev` MCP into the `scripts/agent-wrapper.sh`.
- Ensure all agents (Gemini, Qwen, etc.) have access to these tools by default.

## 3. Success Criteria
- [ ] Agents use the `propose_milestone` tool to suggest additions to the project plan.
- [ ] Task handoffs are performed via the MCP tool instead of manual messages.
- [ ] System prompts for all agents are reduced in size and complexity.
