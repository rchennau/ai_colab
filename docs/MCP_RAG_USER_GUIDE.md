# MCP Server & RAG Integration - User Guide

**Version:** 1.0.0  
**Last Updated:** March 27, 2026

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [MCP Server](#mcp-server)
3. [RAG System](#rag-system)
4. [Web UI](#web-ui)
5. [Troubleshooting](#troubleshooting)
6. [API Reference](#api-reference)

---

## Quick Start

### Installation

```bash
# Install MCP dependencies
pip install -r requirements-mcp.txt

# Install RAG dependencies
pip install -r requirements-rag.txt

# Install test dependencies (optional)
pip install -r requirements-test.txt
```

### Setup LLM-CLI Integration

```bash
# Automated setup for all clients
./scripts/setup-mcp-clients.sh --all

# Or setup individual clients
./scripts/setup-mcp-clients.sh --gemini
./scripts/setup-mcp-clients.sh --qwen
```

### Test Installation

```bash
# Run test suite
./scripts/run-tests.sh --all

# Test MCP server
python -m mcp.ai_colab_server

# Test RAG indexing
python -c "from rag import index_documents; print(index_documents())"
```

---

## MCP Server

### What is MCP?

The **Model Context Protocol (MCP)** server provides standardized tool access for LLM-CLIs. It exposes ai-colab capabilities as callable tools.

### Available Tools

| Tool | Description | Example |
|------|-------------|---------|
| `blackboard_get` | Retrieve value from KV store | "Get current task from blackboard" |
| `blackboard_set` | Set value in KV store | "Store this result" |
| `tracks_read` | Read project tracks | "What's the project status?" |
| `tracks_update` | Update task status | "Mark Phase 2.1 complete" |
| `kb_search` | Search knowledge base | "Find MCP architecture docs" |
| `kb_index` | Trigger indexing | "Re-index knowledge base" |
| `kb_stats` | Get index statistics | "How many docs indexed?" |
| `agent_spawn` | Spawn remote agent | "Spawn reviewer agent" |
| `agent_list` | List active agents | "Which agents running?" |
| `git_sync` | Sync git repository | "Pull latest changes" |
| `build_trigger` | Trigger build | "Run the build" |
| `health_check` | Check system health | "Is system healthy?" |

### Running the MCP Server

**stdio Transport (for LLM-CLI):**

```bash
python -m mcp.ai_colab_server
```

**SSE Transport (for web clients):**

```bash
python -c "
from mcp.ai_colab_server.transports.sse import create_sse_transport
create_sse_transport(background=True)
"
```

### Configuration

**gemini-cli** (`~/.gemini-cli/config.toml`):

```toml
[mcp.servers.ai-colab]
name = "ai-colab"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
transport = "stdio"
working_directory = "/path/to/ai_colab"
```

**qwen-code** (`~/.qwen/config.toml`):

```toml
[mcp.servers.ai-colab]
name = "ai-colab"
type = "stdio"
command = "python"
args = ["-m", "mcp.ai_colab_server"]
cwd = "/path/to/ai_colab"
```

---

## RAG System

### What is RAG?

**Retrieval-Augmented Generation (RAG)** provides semantic search over your codebase and documentation.

### Components

- **Indexer** - Chunks and embeds documents
- **Vector Store** - SQLite database with embeddings
- **Retriever** - Semantic search with re-ranking
- **Cache** - Query result caching

### Indexing Documents

**Command Line:**

```bash
# Index all documents
./scripts/hcom-kb-search.sh --index

# Force re-indexing
./scripts/hcom-kb-search.sh --index --force
```

**Python:**

```python
from rag.client import RAGClient

client = RAGClient()
result = client.index(force=True)

print(f"Indexed {result['files_indexed']} files")
print(f"Created {result['chunks_created']} chunks")
```

**Web UI:**
1. Navigate to http://localhost:8080
2. Click "Knowledge Base" tab
3. Click "🔄 Re-index"

### Searching

**Command Line:**

```bash
# Basic search
./scripts/hcom-kb-search.sh "How does the blackboard work?"

# With filters
./scripts/hcom-kb-search.sh "MCP architecture" --top-k 10 --source "conductor/*"
```

**Python:**

```python
from rag.client import RAGClient

client = RAGClient()

# Search
results = client.search("blackboard architecture", top_k=5)

# Search with filters
results = client.search(
    "MCP server",
    top_k=10,
    filters={'source': 'conductor/*'}
)

# Get statistics
stats = client.get_stats()
print(f"Documents: {stats['document_count']}")
```

**Web UI:**
1. Navigate to "Knowledge Base" tab
2. Enter search query
3. Adjust filters (results count, source)
4. View results with relevance scores

### Auto-Refresh

Start file watcher for automatic re-indexing:

```bash
./launch.sh --rag-watcher
```

The watcher monitors:
- `conductor/*.md`
- `conductor/tracks/**/*.md`
- `system-prompts/*.md`
- `docs/*.md`
- And more...

---

## Web UI

### Access

```bash
# Start Web UI
python webui/app.py

# Or via launcher
./launch.sh
```

Navigate to: **http://localhost:8080**

### Knowledge Base Page

**Features:**
- Semantic search with relevance scores
- Source filtering
- Result excerpts
- Indexing controls
- Statistics dashboard

**Usage:**
1. Enter search query
2. Select result count (3/5/10/20)
3. Filter by source (optional)
4. Review results

---

## Troubleshooting

### MCP Server Won't Start

**Problem:** `ModuleNotFoundError: No module named 'fastmcp'`

**Solution:**
```bash
pip install -r requirements-mcp.txt
```

### RAG Search Returns No Results

**Problem:** Index is empty

**Solution:**
```bash
# Run indexing
./scripts/hcom-kb-search.sh --index

# Or via Web UI: Knowledge Base → Re-index
```

### File Watcher Not Starting

**Problem:** `ModuleNotFoundError: No module named 'watchdog'`

**Solution:**
```bash
pip install watchdog
# Or
pip install -r requirements-rag.txt
```

### Web UI Port Already in Use

**Problem:** `Address already in use`

**Solution:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill process
kill -9 <PID>

# Or use different port
python webui/app.py --port 8081
```

---

## API Reference

### MCP Tools

#### blackboard_get

```python
async def blackboard_get(key: str) -> dict:
    """Retrieve value from blackboard."""
```

**Returns:**
```json
{
  "key": "string",
  "value": any,
  "timestamp": "ISO8601",
  "status": "success|not_found|error"
}
```

#### tracks_read

```python
async def tracks_read() -> dict:
    """Read project tracks."""
```

**Returns:**
```json
{
  "status": "success",
  "milestones": [...],
  "tracks": [...],
  "progress": {
    "total_tracks": 10,
    "completed": 8,
    "percentage": 80.0
  }
}
```

#### kb_search

```python
async def kb_search(query: str, top_k: int = 5) -> list:
    """Search knowledge base."""
```

**Returns:**
```json
[
  {
    "doc": "string",
    "section": "string",
    "score": 0.85,
    "source": "conductor/product.md",
    "excerpt": "..."
  }
]
```

### Web UI API

#### GET /api/kb/search

**Parameters:**
- `query` (required): Search query
- `top_k` (optional): Results count (default: 5)
- `source` (optional): Source filter pattern

**Response:** List of search results

#### POST /api/kb/index

**Response:**
```json
{
  "status": "success",
  "files_processed": 50,
  "files_indexed": 45,
  "chunks_created": 200,
  "elapsed_seconds": 5.2
}
```

#### GET /api/kb/stats

**Response:**
```json
{
  "document_count": 200,
  "database_size_mb": 15.5,
  "cache": {
    "entries": 50,
    "hit_rate_percent": 65.0
  }
}
```

---

## Testing

### Run All Tests

```bash
./scripts/run-tests.sh --all
```

### Run Specific Tests

```bash
# Unit tests only
./scripts/run-tests.sh --unit

# Integration tests
./scripts/run-tests.sh --integration

# Security audit
./scripts/run-tests.sh --security

# Benchmarks
./scripts/run-tests.sh --benchmarks
```

### Manual Testing

```bash
# Test MCP tools
python -c "
from mcp.ai_colab_server.tools import tracks
import asyncio

async def test():
    result = await tracks.tracks_read()
    print(f'Tracks: {result[\"progress\"]}')

asyncio.run(test())
"
```

---

## Performance Benchmarks

**Target Metrics:**

| Metric | Target |
|--------|--------|
| MCP tool latency (p50) | < 100ms |
| MCP tool latency (p99) | < 500ms |
| RAG search latency (p50) | < 200ms |
| RAG search latency (p99) | < 1s |
| Indexing throughput | 100 docs/sec |
| Cache hit rate | > 50% |

**Run Benchmarks:**

```bash
./scripts/run-tests.sh --benchmarks
```

---

## Security

### Run Security Audit

```bash
./scripts/run-tests.sh --security
# Or
python tests/mcp_rag/security_audit.py
```

### Best Practices

1. **Never commit secrets** - Use environment variables
2. **Pin dependencies** - Use `==` in requirements files
3. **Review tool access** - Limit MCP tool permissions
4. **Audit logs** - Enable MCP audit logging

---

## Getting Help

- **Documentation:** `docs/` directory
- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions

---

**End of User Guide**
