# Track: Full Local LLM Support (P5.1)

**ID:** `local_models_20260411`  
**Created:** 2026-04-11  
**Status:** In Progress 🔄  
**Assigned:** @conductor, @architect  
**Priority:** Medium  

---

## Overview

Currently, ai-colab requires at least one cloud-based agent (Gemini, Claude, Qwen) to bootstrap the fleet. P5.1 enables fully air-gapped deployment using local models (Ollama, llama.cpp, local vLLM) with zero external API calls.

**Theme:** "Own your intelligence"

---

## Tasks

### P5.1.1: Ollama Integration

Support Ollama as a local model runtime:
- Model download/management via Ollama CLI
- Agent wrapper for Ollama-based agents
- Health checks and automatic model pulls
- Support for multiple Ollama models simultaneously

**Files:** `scripts/local-models.sh`, `scripts/model-manager.py`

### P5.1.2: llama.cpp Integration

Support llama.cpp for GGUF model execution:
- GGUF model download and quantization management
- Agent wrapper for llama.cpp-based agents
- Memory-optimized inference configuration
- CPU/GPU acceleration selection

**Files:** `scripts/local-models.sh`, `docker/agents/llamacpp/Dockerfile`

### P5.1.3: Local vLLM Expansion

Extend existing remote vLLM support to local deployment:
- Local vLLM Docker container with GPU passthrough
- Model loading and health checks
- Multi-model serving configuration

**Files:** `docker-compose.yml` (update local vLLM service)

### P5.1.4: Model Registry & Management

Centralized model management:
- Model registry with download URLs, sizes, quantization info
- Download scripts with progress tracking and resume support
- Cache management (list, delete, verify integrity)
- Version tracking and update notifications

**Files:** `config/local-models.json`, `scripts/model-manager.py`

### P5.1.5: Zero-Cloud Bootstrap

Ensure conductor can run with only local agents:
- Update agent selection to prefer local models when available
- Conductor loop works without any cloud API keys
- Default fallback to local models when cloud agents unavailable

**Files:** `scripts/conductor-workflow.sh`, `scripts/utils.sh`

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P5.1.1 (Ollama) | None |
| P5.1.2 (llama.cpp) | None |
| P5.1.3 (Local vLLM) | P5.1.1 |
| P5.1.4 (Model Registry) | P5.1.1, P5.1.2 |
| P5.1.5 (Zero-Cloud Bootstrap) | P5.1.1, P5.1.2, P5.1.4 |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Zero-cloud operation | 100% functionality without API keys | Test with no API keys configured |
| Model download reliability | ≥ 95% successful downloads | Download success rate |
| Local inference latency | < 2s for 100-token response | Response timing measurement |
| Memory efficiency | < 8GB RAM for 7B model at Q4 | Memory usage monitoring |
