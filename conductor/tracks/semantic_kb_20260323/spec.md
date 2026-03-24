# Track: Semantic Knowledge Base (RAG-lite)

## 1. Objective
Upgrade the Conductor agent's knowledge search (`!kb`) to provide more accurate, context-aware answers using LLM-based semantic reasoning across the project's documentation and key files.

## 2. Specification

### 2.1 Indexing
- Create a script `scripts/hcom-kb-index.sh` to generate a high-level summary/map of the codebase.
- **Goal**: Provide a compact "Project Map" that can fit within an LLM context window.
- **Content**: Project structure, key files, main functions, and their purposes.

### 2.2 Semantic Search (`!kb`)
- Update the `!kb <query>` command in `scripts/conductor-workflow.sh`:
  1. Pass the user's query and the "Project Map" to an LLM (Gemini).
  2. Ask the LLM to identify the most relevant files/docs for the query.
  3. Retrieve the content of those files.
  4. Generate a comprehensive answer based on the retrieved content.

### 2.3 Knowledge Maintenance
- The "Project Map" should be updated periodically or upon a `!kb-refresh` command.
- Store the map in `conductor/index.md` or a dedicated `conductor/knowledge_base_map.md`.

## 3. Success Criteria
- [ ] `!kb` returns correct answers for queries not explicitly mentioned in the documentation but present in the codebase.
- [ ] Conductor identifies the correct files for a given architectural query.
- [ ] The "Project Map" is automatically generated.
