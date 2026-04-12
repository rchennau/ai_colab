# Senior Code Review & Refactoring Plan (Phase 20+)

## Overview
An extensive review of the codebase reveals several areas suffering from technical debt, redundancy, orphaned code, and inefficient patterns typical of rapid iteration. This plan outlines a systematic refactoring effort to harden the codebase, remove bloat, and elevate the engineering standards.

## 1. Orphaned & Dead Code Removal
- **Deprecated Scripts**: `scripts/cache_manager_deprecated.py` should be removed entirely.
- **Unused Modules**: Verify if `scripts/nemo-cli.py` is fully superseded by `nemoclaw-hcom.sh` or the containerized versions. Remove if obsolete.
- **Stale Tests**: Remove any tests that reference deprecated features (e.g., old manual launch tests).

## 2. Redundancy & Code Bloat Reduction
- **JSON Parsing**: `scripts/utils.sh` contains a fragile, sed-based `extract_json_value` function. This should be replaced by `jq` (if available) or a robust Python one-liner to prevent brittle edge cases.
- **Blackboard Access**: `blackboard_get` and `blackboard_set` are duplicated or slightly varied across multiple scripts. Consolidate into a single, canonical implementation in `utils.sh`.
- **Agent Wrappers**: The individual `${AGENT}-hcom.sh` scripts (gemini, claude, qwen, deepseek) are largely boilerplate calling `agent-wrapper.sh`. These can be consolidated into a single unified launcher or the wrapper itself can handle the specific defaults, eliminating 4-5 files.

## 3. Inefficiency & Performance Optimization
- **Subshell Abuse**: Heavy use of command substitution (e.g., `$(date +%s)`) in tight loops (like `conductor-workflow.sh`) causes significant fork overhead. Cache values where possible.
- **SQLite Transactions**: The Blackboard is currently hammered with individual `sqlite3` calls. `scripts/hcom-kv.sh` needs optimization to batch writes where possible, reducing disk I/O bottlenecks.
- **Polling Loops**: The `sleep 20` and `sleep 60` loops in the conductor and dashboard are inefficient. Transition to event-driven architectures where possible (leveraging `hcom events sub`).

## 4. Security & Hardening
- **Command Injection**: Several shell scripts use `eval "$agent_cmd"` or pass unvalidated variables into `tmux send-keys`. This is a major security risk. All variables must be strictly quoted and sanitized using `printf "%q"`.
- **API Key Handling**: API keys are currently passed via environment variables but sometimes echoed in debug logs or dry-runs. Ensure keys are masked or scrubbed from any output.
- **File Permissions**: Ensure `.env`, `config.toml`, and `.hcom` directories enforce strict `600` or `700` permissions.

## Execution Timeline
1.  **Cleanup**: Delete orphaned files and redundant wrapper scripts.
2.  **Utils Refactor**: Harden `scripts/utils.sh` (JSON parsing, SQLite optimizations).
3.  **Security Audit**: Fix all `eval` and `tmux send-keys` injection vulnerabilities.
4.  **Workflow Optimization**: Reduce subshell overhead in the Conductor's main loop.
5.  **Testing**: Verify all changes against the comprehensive test suite.
