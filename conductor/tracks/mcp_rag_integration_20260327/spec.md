# Specification: MCP Server & RAG Integration

## 1. Overview

This track implements a **hybrid intelligence layer** for ai-colab, combining:
1. **MCP Server** - Structured tool access for LLM-CLIs and IDE integration
2. **RAG Enhancement** - Semantic context retrieval for informed decision-making

## 2. Problem Statement

### Current Limitations
- LLM-CLIs lack standardized tool access across the agent network
- Context sharing relies on manual blackboard updates
- `!kb` command uses basic string matching (limited recall)
- No IDE integration for VS Code/Cursor developers
- Agents must parse full documentation files instead of targeted retrieval

### Desired State
- Unified MCP server exposing ai-colab orchestration capabilities
- Semantic RAG for architectural guidance and codebase understanding
- Both systems work in concert: MCP for **actions**, RAG for **context**

---

## 3. Architecture

### 3.1 High-Level Design

```
┌──────────────────────────────────────────────────────────────────┐
│                         LLM-CLI Clients                          │
│    (Gemini/Qwen/Claude via gemini-cli, qwen-code, etc.)          │
│                              ↕                                   │
│         ┌────────────────────┬────────────────────┐              │
│         │                    │                    │              │
│   MCP Protocol         RAG Queries          hcom Direct         │
│   (Tool Calls)         (Context)            (Messaging)         │
│         │                    │                    │              │
│         └────────────────────┼────────────────────┘              │
│                              ↕                                   │
└──────────────────────────────────────────────────────────────────┘
                              ↕
┌──────────────────────────────────────────────────────────────────┐
│              ai-colab Hub (Orchestration Core)                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │                │  │                │  │                │     │
│  │  MCP Server    │  │  RAG Index     │  │  hcom/kv       │     │
│  │  (FastMCP)     │  │  (SQLite +     │  │  (Blackboard)  │     │
│  │                │  │   embeddings)  │  │                │     │
│  └────────────────┘  └────────────────┘  └────────────────┘     │
│         ↕                    ↕                    ↕             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Core Orchestration Layer                    │    │
│  │  - tracks.md      - config.toml     - agent-wrapper.sh   │    │
│  │  - blackboard     - modules/        - scripts/           │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 MCP Server Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Server Framework** | FastMCP (Python) | MCP protocol implementation |
| **Transport** | stdio + SSE | CLI and HTTP connectivity |
| **Tools** | Python functions | Expose ai-colab capabilities |
| **Resources** | JSON/text | Project state and documentation |
| **Prompts** | Templates | Standardized interaction patterns |

### 3.3 RAG Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Indexing** | Python + SQLite | Document chunking and storage |
| **Embeddings** | sentence-transformers | Semantic vector representations |
| **Retrieval** | Cosine similarity | Top-k relevant document search |
| **Cache** | SQLite | Query result caching |

---

## 4. MCP Server Specification

### 4.1 Tool Definitions

#### **blackboard_get**
```python
@server.tool()
async def blackboard_get(key: str) -> dict:
    """
    Retrieve a value from the shared blackboard (KV store).
    
    Args:
        key: The blackboard key to query
        
    Returns:
        dict: {'key': str, 'value': any, 'timestamp': str}
    """
```

#### **blackboard_set**
```python
@server.tool()
async def blackboard_set(key: str, value: any, ttl: int = 3600) -> dict:
    """
    Set a value in the shared blackboard.
    
    Args:
        key: The blackboard key
        value: The value to store (JSON-serializable)
        ttl: Time-to-live in seconds (default: 1 hour)
        
    Returns:
        dict: {'status': 'success', 'key': str}
    """
```

#### **tracks_read**
```python
@server.tool()
async def tracks_read() -> dict:
    """
    Read the current project tracks from tracks.md.
    
    Returns:
        dict: {'milestones': [...], 'tracks': [...], 'progress': {...}}
    """
```

#### **tracks_update**
```python
@server.tool()
async def tracks_update(task_id: str, status: str, commit_sha: str = None) -> dict:
    """
    Update a task status in tracks.md.
    
    Args:
        task_id: The task identifier (e.g., 'Phase 5.3')
        status: New status ('pending', 'in_progress', 'completed')
        commit_sha: Optional commit hash for completed tasks
        
    Returns:
        dict: {'status': 'success', 'updated_task': str}
    """
```

#### **kb_search**
```python
@server.tool()
async def kb_search(query: str, top_k: int = 5) -> list:
    """
    Search the knowledge base using semantic similarity.
    
    Args:
        query: The search query
        top_k: Number of results to return (default: 5)
        
    Returns:
        list: [{'doc': str, 'score': float, 'source': str, 'excerpt': str}]
    """
```

#### **agent_spawn**
```python
@server.tool()
async def agent_spawn(role: str, task: str, context: dict = None) -> dict:
    """
    Spawn a remote agent for a specific task.
    
    Args:
        role: Agent role (e.g., 'architect', 'developer', 'reviewer')
        task: Task description
        context: Optional context dictionary
        
    Returns:
        dict: {'agent_id': str, 'status': 'spawned', 'channel': str}
    """
```

#### **git_sync**
```python
@server.tool()
async def git_sync(branch: str = None) -> dict:
    """
    Synchronize with git repository.
    
    Args:
        branch: Optional branch name (default: current branch)
        
    Returns:
        dict: {'status': 'success', 'branch': str, 'commit': str}
    """
```

#### **build_trigger**
```python
@server.tool()
async def build_trigger(target: str = 'all') -> dict:
    """
    Trigger a project build.
    
    Args:
        target: Build target (default: 'all')
        
    Returns:
        dict: {'status': 'started', 'build_id': str, 'logs': str}
    """
```

#### **health_check**
```python
@server.tool()
async def health_check() -> dict:
    """
    Check system health status.
    
    Returns:
        dict: {'status': 'healthy'|'unhealthy', 'checks': {...}}
    """
```

### 4.2 Resource Definitions

#### **tracks://current**
```
Resource URI: tracks://current
MIME Type: application/json
Description: Current project tracks state
```

#### **config://active**
```
Resource URI: config://active
MIME Type: application/json
Description: Active configuration
```

#### **kb://index**
```
Resource URI: kb://index
MIME Type: application/json
Description: Knowledge base index metadata
```

### 4.3 Prompt Templates

#### **task-handoff**
```
You are handing off a task to another agent. Provide:
1. Task description
2. Current progress
3. Acceptance criteria
4. Relevant context from blackboard

Task: {{task}}
Assignee: {{assignee}}
Context: {{context}}
```

#### **code-review**
```
Review the following code against project guidelines:
- Style guide: {{style_guide}}
- Security checklist: {{security_checklist}}
- Performance requirements: {{perf_requirements}}

Code: {{code}}
```

---

## 5. RAG Specification

### 5.1 Indexing Strategy

#### Documents to Index

| Source | Type | Chunking |
|--------|------|----------|
| `conductor/*.md` | Markdown | By section (H1/H2) |
| `tracks/**/*.md` | Markdown | By task/phase |
| `system-prompts/*.md` | Markdown | By prompt |
| `modules/**` | Mixed | By file |
| `docs/*.md` | Markdown | By section |
| `scripts/*.sh` | Shell | By function |
| `webui/*.py` | Python | By class/function |

#### Metadata Schema

```json
{
  "id": "uuid",
  "source": "conductor/product.md",
  "section": "Core Pillars",
  "chunk_index": 1,
  "content": "...",
  "embedding": [...],
  "indexed_at": "2026-03-27T10:00:00Z",
  "tags": ["architecture", "pillars"]
}
```

### 5.2 Query Interface

#### Enhanced !kb Command

```bash
# Semantic search
!kb "How does the blackboard work?"

# Filtered search
!kb "agent coordination" --source=conductor/*

# Contextual search (with conversation history)
!kb "this pattern" --context=previous

# Export results
!kb "architecture" --export=json
```

#### Python API

```python
from rag import RAGClient

client = RAGClient()

# Basic search
results = client.search("MCP server architecture", top_k=5)

# Filtered search
results = client.search(
    "agent spawning",
    sources=["conductor/*", "tracks/*"],
    tags=["coordination"]
)

# Similarity search
results = client.similar(document_id, top_k=3)
```

### 5.3 Embedding Configuration

| Parameter | Value |
|-----------|-------|
| **Model** | sentence-transformers/all-MiniLM-L6-v2 |
| **Dimension** | 384 |
| **Similarity** | Cosine |
| **Cache TTL** | 1 hour |

---

## 6. Integration Points

### 6.1 LLM-CLI Integration

#### gemini-cli
```toml
# ~/.gemini-cli/config.toml
[mcp]
enabled = true
servers = ["ai-colab"]

[mcp.servers.ai-colab]
command = "python"
args = ["-m", "ai_colab.mcp.server"]
transport = "stdio"
```

#### qwen-code
```toml
# ~/.qwen/config.toml
[mcp]
enabled = true

[mcp.servers.ai-colab]
endpoint = "http://localhost:8765/sse"
transport = "sse"
```

### 6.2 IDE Integration

#### VS Code Extension
```json
// .vscode/settings.json
{
  "mcp.enabled": true,
  "mcp.servers": {
    "ai-colab": {
      "type": "stdio",
      "command": "python",
      "args": ["-m", "ai_colab.mcp.server"]
    }
  }
}
```

### 6.3 hcom Bridge

```bash
# Forward MCP tool calls via hcom
hcom-mcp-bridge.sh --server ai-colab --channel mcp_requests
```

---

## 7. Security Considerations

### 7.1 Authentication

- MCP server requires API key for remote connections
- Local stdio transport is trusted
- Rate limiting: 100 requests/minute per client

### 7.2 Authorization

| Tool | Permission Level |
|------|------------------|
| blackboard_get | Read |
| blackboard_set | Write |
| tracks_read | Read |
| tracks_update | Write |
| kb_search | Read |
| agent_spawn | Admin |
| git_sync | Write |
| build_trigger | Write |
| health_check | Read |

### 7.3 Data Protection

- No secrets stored in blackboard
- RAG index excludes sensitive files
- Audit logging for all write operations

---

## 8. Performance Requirements

| Metric | Target |
|--------|--------|
| MCP tool latency (p50) | < 100ms |
| MCP tool latency (p99) | < 500ms |
| RAG search latency (p50) | < 200ms |
| RAG search latency (p99) | < 1s |
| Indexing throughput | 100 docs/second |
| Concurrent clients | 10+ |

---

## 9. Success Criteria

### MCP Server
- [ ] All 9 tools implemented and tested
- [ ] stdio and SSE transports working
- [ ] gemini-cli and qwen-code can connect
- [ ] VS Code integration functional
- [ ] Error handling and logging complete

### RAG Enhancement
- [ ] Document indexing pipeline complete
- [ ] Semantic search outperforms keyword search
- [ ] !kb command enhanced with RAG
- [ ] Query caching reduces latency
- [ ] Index auto-refresh on file changes

### Integration
- [ ] MCP tools can invoke RAG searches
- [ ] RAG results include MCP tool suggestions
- [ ] Unified configuration management
- [ ] Comprehensive documentation

---

## 10. Out of Scope

- Custom embedding model training
- Multi-vector retrieval (HyDE, etc.)
- Advanced MCP features (sampling, elicitation)
- Mobile app integration
- Real-time collaborative editing

---

## 11. Future Enhancements

1. **MCP Federation** - Connect multiple ai-colab hubs
2. **RAG Fine-tuning** - Domain-specific embeddings
3. **Graph RAG** - Knowledge graph for architecture
4. **Voice Interface** - Whisper integration for voice commands
5. **Agent Memory** - Long-term conversation history
