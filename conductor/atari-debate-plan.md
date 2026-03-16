# Implementation Plan: Atari-LX Technical Debate

This plan introduces a specialized "Technical Debate" mode for the Atari-LX project, allowing different models (e.g., Qwen and Gemini) to collaborate on architectural and optimization decisions.

## 1. Objectives
- Leverage the existing `debate` script logic but specialize it for Atari-LX.
- Automatically include project context (Blackboard, Build Symbols) in the debate setup.
- Default to using the active agents in the dashboard.
- Create a reusable `atari-debate` command.

## 2. Implementation Steps

### 2.1 `scripts/atari-debate.sh`
Create a wrapper script that simplifies starting a technical debate.

**Features:**
- **Auto-Discovery**: Identify active agents (e.g., `qwen-dev`, `gemini-dev`).
- **Context Injection**: Run `hcom-kv list` and `hcom status` to gather current project metrics.
- **Specialized Roles**:
  - `PRO`: Argues for the proposed change/optimization.
  - `CON`: Argues for stability, readability, or alternative approaches.
  - `JUDGE`: Evaluates based on Atari hardware constraints (CPU cycles, memory usage).
- **Execution**: Calls the underlying `hcom run debate` with injected context and participants.

### 2.2 Dashboard Integration
Update `scripts/dashboard-help.sh` to include information about the `atari-debate` command.

## 3. Verification & Testing

### 3.1 Basic Debate Test
Run a debate on a standard topic:
`bash scripts/atari-debate.sh "Should we use a lookup table for sine wave math?"`

**Success Criteria:**
- The script correctly identifies participants.
- Project symbols/addresses are visible in the debate context.
- Agents engage in at least 2 rounds of rebuttal.
- A verdict is rendered in the `hcom` event stream.

## Key Files
- `scripts/atari-debate.sh` (New)
- `scripts/dashboard-help.sh` (Modified)
