# Track: Cost Optimization & Budget Engine (P5.3)

**ID:** `cost_optimization_20260411`  
**Created:** 2026-04-11  
**Status:** In Progress 🔄  
**Assigned:** @conductor, @architect  
**Priority:** High  

---

## Overview

Currently, there is no cost tracking anywhere in the system. Agent selection is based on capability scores, not cost efficiency. P5.3 implements per-agent token tracking, budget management, and cost-aware routing decisions.

**Theme:** "Spend wisely, optimize continuously"

---

## Tasks

### P5.3.1: Token Usage Tracking

Track token consumption per agent per request:
- Estimate input/output tokens from message lengths
- Store usage in blackboard with timestamps
- Aggregate daily/weekly/monthly totals

**Files:** `scripts/budget-manager.py`

### P5.3.2: Cost Estimation

Convert token usage to cost estimates:
- Per-provider pricing tables (Gemini, Claude, Qwen, DeepSeek, etc.)
- Input vs output token pricing differentiation
- Configurable pricing for model variants

**Files:** `config/pricing.json`, `scripts/budget-manager.py`

### P5.3.3: Budget Management

Configure and enforce spending limits:
- Per-agent budget caps
- Global project budget
- Alert thresholds (50%, 75%, 90%, 100%)
- Automatic agent disabling when budget exceeded

**Files:** `config/budget-config.json`, `scripts/budget-manager.py`

### P5.3.4: Cost-Aware Routing

Integrate cost into agent selection:
- Combine capability scores with cost efficiency
- Prefer cheaper agents when capability difference is marginal
- Route expensive tasks to cost-effective agents

**Files:** `scripts/utils.sh` (agent selection integration)

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P5.3.1 (Token Tracking) | None |
| P5.3.2 (Cost Estimation) | P5.3.1 |
| P5.3.3 (Budget Management) | P5.3.2 |
| P5.3.4 (Cost-Aware Routing) | P5.3.3 |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Token tracking accuracy | ±10% of actual API usage | Comparison with provider invoices |
| Budget alert reliability | 100% of thresholds trigger alerts | Alert log verification |
| Cost-aware routing impact | 15%+ cost reduction | Pre/post routing cost comparison |
| Report generation time | < 1s for 30-day report | Timing measurement |
