# Plan: Semantic Knowledge Base (RAG-lite)

## Phase 1: Codebase Indexing (Project Map)
- [ ] Task: Create `scripts/hcom-kb-index.sh`.
  - [ ] Use `find` and `grep` to build a list of all key project files.
  - [ ] Feed the file list and basic project structure to an LLM (Gemini).
  - [ ] Generate a compact "Project Map" describing the purpose of each directory and core file.
- [ ] Task: Store the result in `conductor/knowledge_base_map.md`.

## Phase 2: Semantic Search (`!kb`)
- [ ] Task: Update the `!kb` logic in `scripts/conductor-workflow.sh`.
  - [ ] When a `!kb` request arrives, pass the query and `knowledge_base_map.md` to Gemini.
  - [ ] Gemini should return a list of file paths (comma-separated).
  - [ ] Conductor reads those files and sends the combined content + query to Gemini for the final answer.
- [ ] Task: Update the TUI and blackboard with search metadata (e.g., `kb_last_query`, `kb_files_used`).

## Phase 3: Knowledge Maintenance
- [ ] Task: Integrate `scripts/hcom-kb-index.sh` into the Conductor's monitoring loop.
  - [ ] Run the indexer once a day or when a `!kb-refresh` command is received.
- [ ] Task: Add the `!kb-refresh` command to the Conductor's command list.

## Phase 4: Verification & Testing
- [ ] Task: Create `tests/test_semantic_kb.sh`.
  - [ ] Verify that the indexer correctly maps the project structure.
  - [ ] Verify that `!kb` uses the map to find relevant files.
