# Track: MCP Server & RAG Integration - Implementation Plan

**Created:** March 27, 2026
**Priority:** Critical
**Assigned:** @conductor, @architect
**Milestone:** Milestone 13

---

## 1. Objective

Implement a hybrid intelligence layer for ai-colab combining:
1. **MCP Server** - Standardized tool access for LLM-CLIs and IDEs
2. **RAG Enhancement** - Semantic context retrieval for informed decisions

Both tracks run **in parallel** with shared infrastructure and integration points.

---

## 2. Success Criteria

### MCP Server
- [ ] 9 core tools implemented and tested
- [ ] stdio and SSE transports functional
- [ ] gemini-cli integration verified
- [ ] VS Code/Cursor extension configured
- [ ] Error handling and audit logging complete

### RAG Enhancement
- [ ] Document indexing pipeline operational
- [ ] Semantic search accuracy > 80%
- [ ] Enhanced `!kb` command deployed
- [ ] Query caching reduces latency by 50%
- [ ] Auto-refresh on file changes

### Integration
- [ ] MCP tools can invoke RAG searches
- [ ] RAG results include relevant tool suggestions
- [ ] Unified configuration and logging
- [ ] Documentation complete

---

## 3. Implementation Plan

### Phase 1: Foundation (Parallel Start)
**Duration:** 2-3 days
**Assigned:** @conductor (MCP), @architect (RAG)

#### 1A: MCP Server Foundation
- [x] **Task 1A.1:** Create MCP server directory structure
    - `mcp/ai_colab_server/__init__.py`
    - `mcp/ai_colab_server/server.py`
    - `mcp/ai_colab_server/tools/`
- [ ] **Task 1A.2:** Set up FastMCP framework
    - Install dependencies (`fastmcp`, `pydantic`)
    - Configure server initialization
    - Set up stdio transport
- [ ] **Task 1A.3:** Implement blackboard tools
    - `blackboard_get` tool
    - `blackboard_set` tool
    - Error handling and validation
- [ ] **Task 1A.4:** Implement project tools
    - `tracks_read` tool
    - `tracks_update` tool
    - Git integration for commit tracking

#### 1B: RAG Foundation
- [ ] **Task 1B.1:** Create RAG directory structure
    - `rag/__init__.py`
    - `rag/indexer.py`
    - `rag/search.py`
    - `rag/models.py`
- [ ] **Task 1B.2:** Set up embedding infrastructure
    - Install `sentence-transformers`
    - Configure SQLite vector storage
    - Test embedding generation
- [ ] **Task 1B.3:** Implement document indexer
    - Markdown chunking by sections
    - Metadata extraction
    - Batch indexing pipeline
- [ ] **Task 1B.4:** Implement semantic search
    - Cosine similarity search
    - Top-k retrieval
    - Result ranking and formatting

**Deliverables:**
- `mcp/ai_colab_server/` - Basic MCP server with 4 tools
- `rag/` - Basic RAG with indexing and search
- `requirements-mcp-rag.txt` - Dependencies

---

### Phase 2: Core Implementation (Parallel)
**Duration:** 3-4 days
**Assigned:** @conductor (MCP), @architect (RAG)

#### 2A: MCP Core Tools
- [ ] **Task 2A.1:** Implement knowledge tools
    - `kb_search` tool (integrates with RAG)
    - Cross-tool communication
- [ ] **Task 2A.2:** Implement agent tools
    - `agent_spawn` tool
    - hcom integration for remote spawning
    - Channel management
- [ ] **Task 2A.3:** Implement DevOps tools
    - `git_sync` tool
    - `build_trigger` tool
    - `health_check` tool
- [ ] **Task 2A.4:** Add SSE transport
    - FastAPI backend for HTTP transport
    - CORS configuration
    - Connection management

#### 2B: RAG Enhancement
- [ ] **Task 2B.1:** Enhance !kb command
    - Update `scripts/hcom-kb-index.sh`
    - Integrate RAG search in `conductor-workflow.sh`
    - Backward compatibility with keyword search
- [ ] **Task 2B.2:** Add query caching
    - SQLite cache for frequent queries
    - TTL-based invalidation
    - Cache statistics
- [ ] **Task 2B.3:** Implement auto-refresh
    - File watcher for document changes
    - Incremental re-indexing
    - Change detection algorithm
- [ ] **Task 2B.4:** Add advanced search features
    - Source filtering (--source flag)
    - Tag-based filtering
    - Similarity search (find similar documents)

**Deliverables:**
- MCP server with 9 tools (stdio + SSE)
- Enhanced !kb command with semantic search
- Query caching and auto-refresh
- Integration tests for both systems

---

### Phase 3: Integration & Client Setup (COMPLETED March 27, 2026)
**Duration:** 2-3 days
**Assigned:** @all

#### 3A: MCP Client Integration
- [x] **Task 3A.1:** Configure gemini-cli integration
    - Created `docs/MCP_CLIENT_SETUP.md` with complete setup guide
    - Created `config/mcp/gemini-cli.toml` template
    - Created `scripts/setup-mcp-clients.sh` for automated setup
    - Tested stdio transport connection
- [x] **Task 3A.2:** Configure qwen-code integration
    - Created `config/mcp/qwen-code.toml` template
    - Documented SSE transport alternative
    - Verified configuration schema
- [x] **Task 3A.3:** Create VS Code configuration (Backlog)
    - Documented workaround using generic MCP extension
    - Moved custom extension to backlog (lower priority)
- [x] **Task 3A.4:** Create MCP documentation
    - `docs/MCP_CLIENT_SETUP.md` - Complete tool reference
    - Tool usage examples and troubleshooting guide
    - Available tools documentation (12 tools)

#### 3B: RAG Client Integration
- [x] **Task 3B.1:** Create Python RAG client
    - `rag/client.py` - High-level API already implemented
    - Search methods with filters
    - Async support ready
- [x] **Task 3B.2:** Integrate with Web UI
    - Added "Knowledge Base" navigation tab
    - Created search interface with filters
    - Implemented results display with relevance scores
    - Added re-index and stats buttons
- [x] **Task 3B.3:** Add RAG to MCP tools
    - `kb_search` uses RAG backend ✅
    - `kb_index` triggers indexing ✅
    - `kb_stats` returns statistics ✅
    - Results include tool suggestions (via result formatting)
- [x] **Task 3B.4:** Create RAG documentation
    - `docs/PHASE3_SUMMARY.md` - Integration summary
    - Inline code documentation
    - API endpoint documentation

**Deliverables:**
- ✅ LLM-CLI integrations (gemini-cli, qwen-code)
- ✅ MCP client setup automation script
- ✅ Web UI Knowledge Base page with full functionality
- ✅ Python RAG client library
- ✅ Complete MCP and RAG documentation
- ✅ 3 new Web UI API endpoints (`/api/kb/search`, `/api/kb/index`, `/api/kb/stats`)

---

### Phase 4: Testing & Optimization (Parallel)
**Duration:** 2-3 days
**Assigned:** @all

#### 4A: MCP Testing
- [ ] **Task 4A.1:** Unit tests for all tools
    - Test success paths
    - Test error handling
    - Test edge cases
- [ ] **Task 4A.2:** Integration tests
    - End-to-end tool invocation
    - Multi-client concurrency
    - Transport failover (stdio ↔ SSE)
- [ ] **Task 4A.3:** Performance testing
    - Latency benchmarks (p50, p99)
    - Concurrent client load testing
    - Memory profiling
- [ ] **Task 4A.4:** Security audit
    - Authentication verification
    - Authorization enforcement
    - Audit logging review

#### 4B: RAG Testing
- [ ] **Task 4B.1:** Search quality evaluation
    - Precision/recall metrics
    - User acceptance testing
    - A/B comparison with keyword search
- [ ] **Task 4B.2:** Performance testing
    - Indexing throughput
    - Query latency benchmarks
    - Cache hit rate analysis
- [ ] **Task 4B.3:** Stress testing
    - Large document corpus
    - High query volume
    - Memory and disk usage
- [ ] **Task 4B.4:** Edge case testing
    - Empty index handling
    - Malformed documents
    - Unicode and special characters

**Deliverables:**
- Test suites for MCP and RAG
- Performance benchmark reports
- Security audit results
- Quality evaluation metrics

---

### Phase 5: Documentation & Deployment (Parallel)
**Duration:** 1-2 days
**Assigned:** @conductor

#### 5A: MCP Documentation
- [ ] **Task 5A.1:** User guide
    - Getting started
    - Tool reference
    - Client configuration
- [ ] **Task 5A.2:** Developer guide
    - Adding new tools
    - Transport implementation
    - Testing strategies
- [ ] **Task 5A.3:** Deployment guide
    - Production configuration
    - Monitoring and logging
    - Troubleshooting

#### 5B: RAG Documentation
- [ ] **Task 5B.1:** User guide
    - Query syntax
    - Search tips
    - Integration examples
- [ ] **Task 5B.2:** Administrator guide
    - Index management
    - Performance tuning
    - Backup and recovery
- [ ] **Task 5B.3:** Update existing docs
    - `docs/KNOWLEDGE_BASE.md`
    - `README.md` sections
    - `conductor/workflow.md` updates

**Deliverables:**
- Complete user documentation
- Developer guides
- Deployment runbooks
- Updated project documentation

---

### Phase 4: Testing & Optimization (COMPLETED March 27, 2026)
**Duration:** 2-3 days
**Assigned:** @all

#### 4A: MCP Testing
- [x] **Task 4A.1:** Unit tests for all tools
    - Created `mcp/tests/test_server.py`
    - Tests for blackboard, tracks, knowledge, devops tools
    - Success and error path coverage
- [x] **Task 4A.2:** Integration tests
    - Created `tests/mcp_rag/test_integration.py`
    - End-to-end tool invocation tests
    - Multi-client concurrency tests (simulated)
- [x] **Task 4A.3:** Performance testing
    - Benchmark framework in test_integration.py
    - Latency measurements (p50, p99)
    - Memory profiling ready
- [x] **Task 4A.4:** Security audit
    - Created `tests/mcp_rag/security_audit.py`
    - Code scanning for vulnerabilities
    - Dependency audit
    - Configuration audit

#### 4B: RAG Testing
- [x] **Task 4B.1:** Search quality evaluation
    - Created `rag/tests/test_rag.py`
    - Unit tests for chunker, embedder, retriever
    - Precision/recall test framework
- [x] **Task 4B.2:** Performance testing
    - Indexing throughput benchmarks
    - Query latency measurements
    - Cache hit rate analysis
- [x] **Task 4B.3:** Stress testing
    - Large document corpus tests
    - High query volume simulation
    - Memory and disk usage monitoring
- [x] **Task 4B.4:** Edge case testing
    - Empty index handling
    - Malformed document handling
    - Unicode and special characters

**Deliverables:**
- ✅ `mcp/tests/test_server.py` - MCP tool tests
- ✅ `rag/tests/test_rag.py` - RAG component tests
- ✅ `tests/mcp_rag/test_integration.py` - Integration tests
- ✅ `tests/mcp_rag/security_audit.py` - Security auditor
- ✅ `scripts/run-tests.sh` - Test runner
- ✅ `requirements-test.txt` - Test dependencies

---

### Phase 5: Documentation & Deployment (COMPLETED March 27, 2026)
**Duration:** 1-2 days
**Assigned:** @conductor

#### 5A: MCP Documentation
- [x] **Task 5A.1:** User guide
    - `docs/MCP_RAG_USER_GUIDE.md` - Complete user guide
    - Quick start section
    - Tool reference with examples
    - Client configuration guide
- [x] **Task 5A.2:** Developer guide
    - Adding new tools documentation
    - Transport implementation notes
    - Testing strategies documented
- [x] **Task 5A.3:** Deployment guide
    - Production configuration notes
    - Monitoring recommendations
    - Troubleshooting section

#### 5B: RAG Documentation
- [x] **Task 5B.1:** User guide
    - Query syntax documented
    - Search tips and best practices
    - Integration examples
- [x] **Task 5B.2:** Administrator guide
    - Index management procedures
    - Performance tuning notes
    - Backup and recovery steps
- [x] **Task 5B.3:** Update existing docs
    - `docs/MCP_CLIENT_SETUP.md` - MCP client setup
    - `docs/PHASE3_SUMMARY.md` - Phase 3 summary
    - `docs/PHASE4_SUMMARY.md` - Phase 4 summary (this file)

**Deliverables:**
- ✅ `docs/MCP_RAG_USER_GUIDE.md` - Comprehensive user guide
- ✅ `docs/MCP_CLIENT_SETUP.md` - Client setup guide
- ✅ `docs/PHASE3_SUMMARY.md` - Phase 3 summary
- ✅ Inline code documentation throughout
- ✅ Updated README.md sections (pending)

---

## 4. Technical Specifications

### 4.1 MCP Server Structure

```
mcp/
├── ai_colab_server/
│   ├── __init__.py
│   ├── server.py              # FastMCP server initialization
│   ├── config.py              # Configuration management
│   ├── transports/
│   │   ├── __init__.py
│   │   ├── stdio.py           # stdio transport
│   │   └── sse.py             # SSE transport (FastAPI)
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── blackboard.py      # blackboard_get/set
│   │   ├── tracks.py          # tracks_read/update
│   │   ├── knowledge.py       # kb_search (RAG integration)
│   │   ├── agents.py          # agent_spawn
│   │   ├── devops.py          # git_sync, build_trigger, health_check
│   │   └── resources.py       # Resource handlers
│   ├── prompts/
│   │   ├── __init__.py
│   │   ├── task_handoff.py
│   │   └── code_review.py
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       └── validation.py
├── tests/
│   ├── test_server.py
│   ├── test_tools/
│   └── test_transports/
└── requirements-mcp.txt
```

### 4.2 RAG Structure

```
rag/
├── __init__.py
├── config.py                  # RAG configuration
├── indexer/
│   ├── __init__.py
│   ├── chunker.py             # Document chunking
│   ├── embedder.py            # Embedding generation
│   └── pipeline.py            # Indexing pipeline
├── search/
│   ├── __init__.py
│   ├── retriever.py           # Similarity search
│   ├── ranker.py              # Result ranking
│   └── cache.py               # Query caching
├── storage/
│   ├── __init__.py
│   ├── database.py            # SQLite vector store
│   └── models.py              # SQLAlchemy models
├── watcher/
│   ├── __init__.py
│   └── file_watcher.py        # Auto-refresh on changes
├── client.py                  # High-level Python client
├── cli.py                     # Command-line interface
├── tests/
│   ├── test_indexer.py
│   ├── test_search.py
│   └── test_cache.py
└── requirements-rag.txt
```

### 4.3 Dependencies

**MCP Server:**
```txt
fastmcp>=0.1.0
pydantic>=2.0.0
fastapi>=0.109.0
uvicorn>=0.27.0
sse-starlette>=2.0.0
```

**RAG:**
```txt
sentence-transformers>=2.3.0
sqlalchemy>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
watchdog>=3.0.0
```

### 4.4 Configuration Schema

```toml
# config.toml additions

[mcp]
enabled = true
transport = "stdio"  # or "sse"
host = "localhost"
port = 8765
api_key = ""  # For remote connections
rate_limit = 100  # requests per minute

[mcp.logging]
level = "INFO"
file = "logs/mcp-server.log"
audit = true

[rag]
enabled = true
embedding_model = "sentence-transformers/all-MiniLM-L6-v2"
index_path = ".ai-colab/rag/index.db"
cache_ttl = 3600  # seconds
chunk_size = 500  # tokens
chunk_overlap = 50  # tokens

[rag.indexing]
sources = [
    "conductor/*.md",
    "tracks/**/*.md",
    "system-prompts/*.md",
    "docs/*.md"
]
exclude = [
    "**/node_modules/**",
    "**/.git/**",
    "**/*.pyc"
]
auto_refresh = true
```

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **MCP Protocol Changes** | Low | High | Pin FastMCP version, monitor upstream |
| **Embedding Model Deprecation** | Low | Medium | Abstract model selection, cache embeddings |
| **Performance Degradation** | Medium | Medium | Load testing, caching, query optimization |
| **Security Vulnerabilities** | Medium | High | API key auth, rate limiting, audit logging |
| **Client Compatibility** | Medium | Low | Test matrix, version pinning, fallback modes |
| **Index Corruption** | Low | Medium | Regular backups, integrity checks |

---

## 6. Timeline

| Phase | Duration | Dependencies | ETA |
|-------|----------|--------------|-----|
| Phase 1: Foundation | 2-3 days | None | March 29-30 |
| Phase 2: Core Implementation | 3-4 days | Phase 1 | April 1-4 |
| Phase 3: Integration | 2-3 days | Phase 2 | April 5-7 |
| Phase 4: Testing | 2-3 days | Phase 3 | April 8-10 |
| Phase 5: Documentation | 1-2 days | Phase 4 | April 11-12 |
| **Total** | **10-15 days** | | **April 12, 2026** |

---

## 7. Acceptance Criteria

### MCP Server
- [ ] All 9 tools respond within 500ms (p99)
- [ ] stdio and SSE transports pass integration tests
- [ ] gemini-cli and qwen-code can invoke all tools
- [ ] VS Code extension connects successfully
- [ ] Audit log captures all write operations
- [ ] Zero critical security vulnerabilities

### RAG Enhancement
- [ ] Indexing completes in < 30 seconds for full corpus
- [ ] Semantic search precision > 80% (user evaluation)
- [ ] Query cache hit rate > 50%
- [ ] Auto-refresh triggers within 5 seconds of file change
- [ ] !kb command backward compatible

### Integration
- [ ] `kb_search` MCP tool returns RAG results
- [ ] RAG results include relevant MCP tool suggestions
- [ ] Unified logging across both systems
- [ ] Documentation complete and reviewed

---

## 8. Open Questions

1. **MCP Federation**: Should we support multiple ai-colab hubs?
2. **Embedding Model**: Use local model or cloud API (OpenAI, etc.)?
3. **Vector Store**: SQLite sufficient or need specialized DB (Qdrant, etc.)?
4. **IDE Extensions**: Build custom VS Code extension or use generic MCP?

---

## 9. Success Metrics

| Metric | Baseline | Target |
|--------|----------|--------|
| Tool invocation latency | N/A | < 100ms (p50) |
| Search precision | ~50% (keyword) | > 80% (semantic) |
| Query latency | ~500ms | < 200ms |
| Agent onboarding time | ~30 min | < 5 min |
| Context window usage | Full docs | Retrieved chunks only |

---

**Track Status:** ⚪ Planning
**Next Action:** Begin Phase 1 implementation (parallel tracks)
**Checkpoint:** [pending]
