# Plan: Semantic Knowledge Base (RAG-lite)

## Phase 1: Codebase Indexing (Project Map)
- [x] Task: Create `scripts/hcom-kb-index.sh`.
  - [x] Use `find` and `grep` to build a list of all key project files.
  - [x] Feed the file list and basic project structure to an LLM (Gemini).
  - [x] Generate a compact "Project Map" describing the purpose of each directory and core file.
- [x] Task: Store the result in `conductor/knowledge_base_map.md`.


## Phase 2: Semantic Search (`!kb`)
- [x] Task: Update the `!kb` logic in `scripts/conductor-workflow.sh`.
  - [x] When a `!kb` request arrives, pass the query and `knowledge_base_map.md` to Gemini.
  - [x] Gemini should return a list of file paths (comma-separated).
  - [x] Conductor reads those files and sends the combined content + query to Gemini for the final answer.
- [x] Task: Update the TUI and blackboard with search metadata (e.g., `kb_last_query`, `kb_files_used`).

## Phase 3: Knowledge Maintenance
- [x] Task: Integrate `scripts/hcom-kb-index.sh` into the Conductor's monitoring loop.
  - [x] Run the indexer once every 12 hours or when a `!kb-refresh` command is received.
- [x] Task: Add the `!kb-refresh` command to the Conductor's command list.


## Phase 4: Verification & Testing
- [x] Task: Create `tests/test_semantic_kb.sh`.
  - [x] Verify that the indexer correctly maps the project structure.
  - [x] Verify that `!kb` uses the map to find relevant files.

