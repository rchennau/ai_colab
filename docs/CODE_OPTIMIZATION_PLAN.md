# Code Optimization Plan - Phase 2

**Date:** March 27, 2026  
**Goal:** Further reduce complexity and optimize code

---

## Identified Issues

### **1. Duplicate Cache Implementations** ❌

**Current:**
- `scripts/utils_core.py::SimpleCache` (613 lines)
- `scripts/cache_manager.py::CacheManager` (654 lines)
- `scripts/cache_manager.py::RedisCache` 
- `scripts/cache_manager.py::MemoryCache`

**Problem:** 3 different cache implementations doing similar things

**Solution:** 
- Keep `SimpleCache` in utils_core.py (has smart TTL)
- Deprecate `cache_manager.py` (redirect to utils_core)
- Add Redis support to SimpleCache if needed

**Savings:** -600 lines

---

### **2. Large Data Classes Without Validation** ⚠️

**Current:**
```python
@dataclass
class InferenceRequest:
    request_id: str
    prompt: str
    # ... many fields
```

**Problem:** No validation, can create invalid objects

**Solution:** Add Pydantic validation
```python
from pydantic import BaseModel, Field

class InferenceRequest(BaseModel):
    request_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1, max_length=100000)
    max_tokens: int = Field(default=1024, ge=1, le=32768)
```

**Benefits:**
- Automatic validation
- Better error messages
- Self-documenting

---

### **3. Monolithic Gateway File** ❌

**Current:** `scripts/inference/gateway.py` (1,137 lines)

**Problem:** Too many responsibilities

**Solution:** Split into modules:
```
inference/
├── __init__.py
├── gateway.py          # Main orchestrator (200 lines)
├── models.py           # Data models (150 lines)
├── clients/            # Model clients
│   ├── __init__.py
│   ├── gemini.py
│   ├── qwen.py
│   └── claude.py
├── routing.py          # Model routing (150 lines)
├── batching.py         # Request batching (150 lines)
└── caching.py          # Caching layer (150 lines)
```

**Savings:** Each file <200 lines, easier to maintain

---

### **4. Agent Federation Complexity** ⚠️

**Current:** `scripts/agent_federation.py` (1,028 lines)

**Problem:** Coordination and Learning mixed together

**Solution:** Split into separate systems:
```
federation/
├── __init__.py
├── coordination.py     # Agent coordination (400 lines)
├── learning.py         # Federated learning (400 lines)
└── models.py           # Data models (150 lines)
```

---

### **5. Missing Type Hints** ⚠️

**Current:** Mixed type hint usage

**Problem:** Harder to catch type errors

**Solution:** Add comprehensive type hints
```python
# Before
def get_cache(key, namespace=None):
    return cache.get(key, namespace)

# After
def get_cache(key: str, namespace: Optional[str] = None) -> Any:
    return cache.get(key, namespace)
```

---

### **6. Error Handling Inconsistency** ⚠️

**Current:** Mix of patterns:
- Return `{'status': 'error'}`
- Raise exceptions
- Return None

**Solution:** Standardize on exceptions
```python
# Standard pattern
try:
    result = operation()
except AIColabError as e:
    logger.error(f"Operation failed: {e}")
    raise
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise InferenceError(f"Operation failed: {e}") from e
```

---

## Implementation Priority

### **Week 1: Quick Wins**
1. ✅ Add Pydantic validation (2 days)
2. ✅ Add comprehensive type hints (2 days)
3. ✅ Standardize error handling (1 day)

**Expected:** Better IDE support, fewer bugs

### **Week 2: Code Splitting**
1. Split inference gateway (2 days)
2. Split agent federation (2 days)
3. Remove duplicate cache (1 day)

**Expected:** -1,200 lines, better maintainability

### **Week 3: Performance**
1. Profile hot paths (1 day)
2. Optimize database queries (2 days)
3. Add async database support (2 days)

**Expected:** 2x performance improvement

---

## Metrics

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| **Largest File** | 2,080 lines | <500 lines | <300 |
| **Avg File Size** | 400 lines | 200 lines | <200 |
| **Type Coverage** | 60% | 95% | 100% |
| **Duplicate Code** | 5% | <2% | <2% |
| **Cyclomatic Complexity** | 15 avg | <10 | <8 |

---

**Status:** Plan documented  
**Next:** Implement Phase 2 optimizations
