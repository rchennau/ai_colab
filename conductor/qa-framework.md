# QA Framework: ai-colab

**Version:** 1.0  
**Date:** 2026-04-10  
**Status:** Active  

---

## 1. Quality Objectives

| Objective | Target | Measurement |
|-----------|--------|-------------|
| Test Coverage | ≥ 80% | `pytest --cov` reports |
| Critical Bugs in Production | 0 | Post-release incident tracking |
| Test Execution Time | < 10 min (CI) | CI/CD pipeline duration |
| Shell Script Reliability | ≥ 95% pass rate | `test-all.sh` results |
| Docker Build Success | 100% | Docker build job status |
| Code Review Coverage | 100% of PRs | GitHub PR review requirements |

---

## 2. Test Pyramid

```
                    ┌─────────────┐
                    │   E2E (5%)  │  Full system validation
                   ┌┴──────────────┴┐
                  │ Integration (15%)│  Cross-component testing
                 ┌┴──────────────────┴┐
                │   Unit Tests (30%)   │  Python modules, utilities
               ┌┴──────────────────────┴┐
              │  Shell Tests (30%)       │  Scripts, workflows, launchers
             ┌┴──────────────────────────┴┐
            │  Static Analysis (20%)       │  Linting, type checking, security
            └──────────────────────────────┘
```

---

## 3. Test Categories

### 3.1 Unit Tests (Python)
**Location:** `tests/test_*.py`  
**Runner:** `pytest`  
**Coverage:** Web UI, MCP server, RAG system, inference gateway

| Test File | Components Tested | Status |
|-----------|-------------------|--------|
| `test_integration.py` | Inference Gateway, Model Registry, Agent Federation | ✅ Active |
| `test_inference_gateway.py` | Validator, Router, Cache, Rate Limiter | ✅ Active |
| `test_workspace_manager.py` | Git repo discovery, project registration | ✅ Active |
| `tests/mcp_rag/test_integration.py` | MCP tools, RAG indexing/search | ✅ Active |
| `tests/mcp_rag/security_audit.py` | MCP/RAG security checks | ✅ Active |

**Execution:**
```bash
# Run all unit tests
pytest tests/test_*.py tests/mcp_rag/test_*.py -v

# With coverage
pytest tests/ --cov=webui --cov=mcp --cov=rag --cov-report=html
```

### 3.2 Shell Script Tests
**Location:** `tests/test_*.sh`  
**Runner:** `bash` (via `test-all.sh`)  
**Coverage:** Core scripts, launchers, conductor, agents

| Test File | Components Tested | Dependencies |
|-----------|-------------------|--------------|
| `test_webui.sh` | Flask API endpoints | tmux, hcom, Python |
| `test_docker_core.sh` | Docker image verification | Docker |
| `test_qa_commands.sh` | Conductor command processing | hcom, blackboard |
| `test_blackboard.sh` | KV store operations | sqlite3 |
| `test_conductor_workflow.sh` | Blackboard-to-tracks sync | hcom, conductor |
| `test_semantic_kb.sh` | RAG indexing and search | sentence-transformers |
| `test_git_lifecycle.sh` | Branch/PR automation | git, hcom |
| `test_fleet_autonomy.sh` | Health monitoring | hcom, agents |
| `test_fleet_recovery.sh` | Crash recovery | hcom, agents |
| `test_module_hooks.sh` | Plugin system | module-manager |
| `test_track_dependencies.sh` | Dependency resolution | hcom |
| `test_portable_python.sh` | Python isolation | uv |
| `test_python_env_optimization.sh` | Environment detection | uv/conda/venv |
| `test_install_wizard.sh` | Installation flow | brew/apt |
| `test_config_manager.sh` | Configuration management | sqlite3 |
| `test_dashboard_*.sh` | Dashboard TUI | tmux |
| `test_launch_qwen_gemini.sh` | LLM CLI launch | qwen-code, gemini-cli |
| `test_migration.sh` | Project migration | git |
| `test_terminal_detect.sh` | Terminal detection | iTerm2/WSL |
| `test_code_review.sh` | Code review automation | git, hcom |

**Execution:**
```bash
# Run all shell tests
bash scripts/test-all.sh --skip-webui --skip-docker

# Run specific test
bash tests/test_blackboard.sh
```

### 3.3 Integration Tests
**Location:** `tests/test_integration.py`, `tests/mcp_rag/`  
**Runner:** `pytest`  
**Coverage:** Cross-component workflows, end-to-end flows

| Test | Scenario | Expected Result |
|------|----------|-----------------|
| Inference Gateway | Route request → model → response | Correct model selected, response returned |
| Model Registry | Register → query → validate | Model metadata stored and retrievable |
| Agent Federation | Spawn → heartbeat → status | Agent registered, healthy, visible |
| MCP-RAG Integration | Index → search → verify | Results match query relevance |

**Execution:**
```bash
# Run integration tests (slow)
bash scripts/test-all.sh --only integration
```

### 3.4 End-to-End Tests
**Location:** `scripts/test-webui-e2e.sh`, `scripts/test-webui-playwright.py`  
**Runner:** Playwright / bash  
**Coverage:** Full user workflows

| Test | Workflow | Steps |
|------|----------|-------|
| Web UI E2E | Launch → navigate → interact → verify | Server starts, pages load, API responds |
| Playwright E2E | Browser automation | UI elements visible, interactions work |
| Dashboard Launch | launch.sh → tmux → agents | Dashboard creates, agents launch |

**Execution:**
```bash
# Run E2E tests
bash scripts/test-webui-e2e.sh
python scripts/test-webui-playwright.py
```

### 3.5 Static Analysis
**Runner:** flake8, black, shellcheck, pylint  
**Coverage:** Code quality, style, security

| Tool | Target | Configuration |
|------|--------|---------------|
| flake8 | Python files | Critical errors only (E9,F63,F7,F82) |
| black | Python formatting | Default config |
| shellcheck | Shell scripts | Default config |
| pylint | Python quality | Threshold: 7.0/10 |

---

## 4. CI/CD Pipeline

### 4.1 Pipeline Stages

```
Push/PR → Lint & Analysis → Unit Tests → Shell Tests → Web UI Tests → Docker Build → Integration Tests (main only)
```

### 4.2 Stage Details

| Stage | Trigger | Timeout | Fail Behavior |
|-------|---------|---------|---------------|
| Lint & Analysis | All pushes/PRs | 5 min | Warning (continue) |
| Unit Tests | All pushes/PRs | 10 min | Block merge |
| Shell Tests | All pushes/PRs | 15 min | Warning (continue) |
| Web UI Tests | All pushes/PRs | 10 min | Block merge |
| Docker Build | All pushes/PRs | 10 min | Warning (continue) |
| Integration Tests | main branch only | 30 min | Warning (continue) |

### 4.3 Quality Gates

| Gate | Condition | Action |
|------|-----------|--------|
| Unit Tests | All must pass | Block PR merge |
| Web UI Tests | All must pass | Block PR merge |
| Test Coverage | ≥ 80% | Warning if below |
| Security Scan | No critical vulns | Block if critical |
| Shell Check | No errors | Warning for warnings |

### 4.4 Running the Pipeline Locally

```bash
# Full test suite
bash scripts/test-all.sh

# CI-mode (machine-readable output)
bash scripts/test-all.sh --ci

# Skip slow tests
bash scripts/test-all.sh --skip-slow

# Skip integration tests
bash scripts/test-all.sh --skip-integration

# Run specific suite
bash scripts/test-all.sh --skip-shell --skip-docker --skip-integration
```

---

## 5. Quality Gates for Releases

### 5.1 Pre-Release Checklist

- [ ] All unit tests passing
- [ ] All Web UI tests passing
- [ ] All shell tests passing (≥ 95%)
- [ ] Docker build succeeds
- [ ] Test coverage ≥ 80%
- [ ] No critical security vulnerabilities
- [ ] Manual smoke test completed
- [ ] Release notes drafted and reviewed

### 5.2 Release Types

| Type | Criteria | Testing Required |
|------|----------|------------------|
| **Patch** (0.0.x) | Bug fixes only | Unit + Web UI tests |
| **Minor** (0.x.0) | New features | Full test suite |
| **Major** (x.0.0) | Breaking changes | Full suite + manual QA review |

---

## 6. Test Data Management

### 6.1 Test Fixtures

| Fixture | Location | Purpose |
|---------|----------|---------|
| Mock hcom events | `tests/fixtures/hcom-events.json` | Event processing tests |
| Sample config | `tests/fixtures/config.toml` | Config manager tests |
| Test tracks | `tests/fixtures/tracks.md` | Conductor workflow tests |
| Mock embeddings | `tests/fixtures/embeddings.npy` | RAG system tests |

### 6.2 Test Isolation

- Each test runs in a temporary directory (`/tmp/ai-colab-test-*`)
- Tests clean up after themselves (via `trap`)
- No test modifies production files
- Blackboard tests use separate SQLite database

---

## 7. Performance Benchmarks

| Benchmark | Target | Current | Measurement |
|-----------|--------|---------|-------------|
| Blackboard: 100 writes | < 1s | ~0.5s | `test_blackboard.sh` |
| Web UI: health check | < 200ms | ~50ms | `test_webui.sh` |
| Conductor: track sync | < 5s | ~2s | `test_conductor_workflow.sh` |
| RAG: search latency | < 1s | ~0.8s | `test_semantic_kb.sh` |
| Test suite: total | < 10 min | ~6 min | CI/CD pipeline |

---

## 8. Defect Management

### 8.1 Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| **Critical** | System crash, data loss, security breach | Immediate (block release) |
| **High** | Feature broken, no workaround | Within 24 hours |
| **Medium** | Feature degraded, workaround exists | Within 1 week |
| **Low** | Cosmetic, minor UX issue | Within 1 sprint |

### 8.2 Bug Lifecycle

```
Reported → Triaged → Assigned → Fix → Review → Test → Merged → Verified
```

### 8.3 Reporting Bugs

Use GitHub Issues with these labels:
- `bug` — Confirmed defect
- `critical` — Blocks release
- `regression` — Worked before, broken now
- `test-gap` — Missing test coverage

---

## 9. Security Testing

### 9.1 Automated Security Checks

| Check | Tool | Frequency |
|-------|------|-----------|
| Dependency vulnerabilities | `pip-audit`, `safety` | Every CI run |
| Secret detection | `gitleaks` | Every CI run |
| Shell script security | `shellcheck` | Every CI run |
| SQL injection | Manual review + test cases | Every PR |
| Path traversal | Manual review + test cases | Every PR |

### 9.2 Security Checklist

- [ ] No hardcoded secrets in codebase
- [ ] No secrets in git history
- [ ] Dependencies up to date
- [ ] Rate limiting enabled on Web UI
- [ ] CORS configured correctly
- [ ] Input validation on all endpoints
- [ ] File upload validation (if applicable)
- [ ] TLS enabled for MQTT (Phase 16)

---

## 10. Continuous Improvement

### 10.1 Metrics Tracked

| Metric | Target | Tool |
|--------|--------|------|
| Test pass rate | ≥ 95% | CI/CD summary |
| Mean time to detect | < 5 min | CI/CD timing |
| Mean time to fix | < 24 hours | GitHub issue tracking |
| Bug escape rate | < 5% | Post-release incidents / total bugs |
| Test flakiness | < 2% | CI retry analysis |

### 10.2 Review Cadence

- **Weekly:** Test pass rate, flaky tests, coverage trends
- **Monthly:** QA framework review, process improvements
- **Per Release:** Release checklist audit, retrospective

---

## 11. Responsibilities

| Role | Responsibility |
|------|----------------|
| **Conductor** | Automated test execution, quality gate enforcement |
| **Developers** | Write tests for new features, fix failing tests |
| **QA (Automated)** | Run test suite, report results, block releases on failures |
| **All Agents** | Review PRs, report bugs, suggest test improvements |

---

*This document is version-controlled and updated via the standard track workflow.*
