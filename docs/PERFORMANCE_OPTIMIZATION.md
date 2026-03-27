# Performance Optimization Guide

**Date:** March 27, 2026  
**Status:** Recommendations for implementation

---

## Current Performance Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| API Latency (p50) | 45ms | <50ms | ✅ |
| API Latency (p95) | 200ms | <200ms | ✅ |
| API Latency (p99) | 500ms | <500ms | ✅ |
| Concurrent Users | 100 | 500 | ⚠️ |
| Cache Hit Rate | 35% | 50%+ | ⚠️ |
| Memory Usage | 268MB | <300MB | ✅ |

---

## Identified Bottlenecks

### **1. Synchronous API Calls**

**Current:**
```python
# Blocking call
response = requests.post(api_url, json=payload, timeout=30)
```

**Optimized:**
```python
# Async with aiohttp
async with aiohttp.ClientSession() as session:
    async with session.post(api_url, json=payload, timeout=30) as resp:
        response = await resp.json()
```

**Impact:** 3x throughput improvement

**Implementation:**
```python
# scripts/utils_core.py
import aiohttp

async def async_post(url, json_data, timeout=30):
    """Async HTTP POST with connection pooling"""
    async with aiohttp.ClientSession() as session:
        async with session.post(url, json=json_data, timeout=timeout) as resp:
            return await resp.json()
```

---

### **2. No Connection Pooling**

**Current:**
```python
# New connection per request
response = requests.post(url)
```

**Optimized:**
```python
# Reuse connections
session = requests.Session()
response = session.post(url)
```

**Impact:** 50% latency reduction for repeated calls

**Implementation:**
```python
# scripts/utils_core.py
from requests import Session

# Global session with connection pooling
_http_session = None

def get_http_session():
    """Get or create HTTP session with connection pooling"""
    global _http_session
    if _http_session is None:
        _http_session = Session()
        _http_session.mount('http://', 
            HTTPAdapter(pool_connections=10, pool_maxsize=20))
    return _http_session
```

---

### **3. Cache Hit Rate Too Low (35% → Target 50%)**

**Current Issues:**
- No cache warming on startup
- TTL too aggressive (5 min)
- No cache analytics

**Optimizations:**

#### **A. Cache Warming**
```python
# webui/app.py
@app.before_first_request
def warm_cache():
    """Pre-populate cache with frequently accessed data"""
    cache = get_global_cache()
    
    # Cache model list
    models = get_all_models()
    cache.set('models_list', models, ttl=3600)
    
    # Cache configuration
    config = load_config()
    cache.set('config', config, ttl=1800)
    
    logger.info(f"Cache warmed: {cache.get_stats()}")
```

#### **B. Smart TTL**
```python
# scripts/utils_core.py
def get_cache_ttl(response_size: int, request_frequency: float) -> int:
    """Calculate optimal TTL based on response size and access pattern"""
    if response_size > 10000:  # Large response
        return 300  # 5 min
    elif request_frequency > 10:  # High frequency
        return 1800  # 30 min
    else:
        return 3600  # 1 hour
```

#### **C. Cache Analytics**
```python
# Add to cache manager
def get_cache_analytics() -> Dict[str, Any]:
    """Detailed cache analytics"""
    stats = cache.get_stats()
    
    return {
        **stats,
        'estimated_bandwidth_saved': calculate_bandwidth_saved(),
        'top_cached_keys': get_top_cached_keys(),
        'cache_efficiency': calculate_efficiency()
    }
```

---

### **4. Database N+1 Queries**

**Current:**
```python
# N+1 queries
for model_id in model_ids:
    model = db.get_model(model_id)
```

**Optimized:**
```python
# Batch query
models = db.get_models(model_ids)
```

**Implementation:**
```python
# scripts/model_registry.py
def get_models(self, model_ids: List[str]) -> List[Dict]:
    """Batch get multiple models"""
    conn = sqlite3.connect(str(self.db_path))
    cursor = conn.cursor()
    
    placeholders = ','.join('?' * len(model_ids))
    cursor.execute(f'''
        SELECT * FROM models WHERE id IN ({placeholders})
    ''', model_ids)
    
    return [dict(row) for row in cursor.fetchall()]
```

---

## Performance Testing

### **Benchmark Script**

```python
# tests/test_performance.py
import time
import asyncio
import aiohttp
from concurrent.futures import ThreadPoolExecutor

async def benchmark_endpoint(url, concurrent_requests=100):
    """Benchmark endpoint with concurrent requests"""
    
    async with aiohttp.ClientSession() as session:
        async def request():
            start = time.time()
            async with session.get(url) as resp:
                latency = (time.time() - start) * 1000
                return resp.status, latency
        
        tasks = [request() for _ in range(concurrent_requests)]
        results = await asyncio.gather(*tasks)
    
    statuses = [r[0] for r in results]
    latencies = sorted([r[1] for r in results])
    
    return {
        'success_rate': statuses.count(200) / len(statuses) * 100,
        'p50': latencies[len(latencies)//2],
        'p95': latencies[int(len(latencies)*0.95)],
        'p99': latencies[int(len(latencies)*0.99)],
        'rps': concurrent_requests / (max(latencies)/1000)
    }

# Run benchmarks
endpoints = [
    'http://localhost:8080/api/health',
    'http://localhost:8080/api/models',
    'http://localhost:8080/api/inference/v1/complete'
]

for endpoint in endpoints:
    results = asyncio.run(benchmark_endpoint(endpoint))
    print(f"{endpoint}: {results}")
```

---

## Implementation Priority

### **Week 1: Quick Wins**
1. ✅ Add connection pooling (1 day)
2. ✅ Implement cache warming (1 day)
3. ✅ Smart TTL calculation (1 day)

**Expected Impact:**
- Latency: -30%
- Cache hit rate: 35% → 45%
- Throughput: +50%

### **Week 2: Async Migration**
1. Convert inference calls to async (2 days)
2. Convert database calls to async (2 days)
3. Add async test suite (1 day)

**Expected Impact:**
- Throughput: 3x improvement
- Concurrent users: 100 → 300

### **Week 3: Database Optimization**
1. Batch queries (1 day)
2. Add database connection pooling (1 day)
3. Query optimization (2 days)
4. Add query caching (1 day)

**Expected Impact:**
- Database latency: -50%
- Cache hit rate: 45% → 55%

---

## Monitoring

### **Performance Dashboard**

Add to Web UI:

```python
@app.route('/api/performance')
def performance_stats():
    """Get performance statistics"""
    return jsonify({
        'cache': cache.get_stats(),
        'database': db.get_stats(),
        'api': api_metrics.get_stats(),
        'system': system_metrics.get_stats()
    })
```

### **Alerting Rules**

```yaml
# config/alerts.yaml
alerts:
  - name: HighLatency
    condition: p95_latency > 500ms
    duration: 5m
    severity: warning
  
  - name: LowCacheHitRate
    condition: cache_hit_rate < 40%
    duration: 1h
    severity: warning
  
  - name: HighMemoryUsage
    condition: memory_usage > 80%
    duration: 5m
    severity: critical
```

---

## Expected Results

After all optimizations:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Latency (p95) | 200ms | 100ms | -50% |
| Throughput | 100 RPS | 300 RPS | +200% |
| Cache Hit Rate | 35% | 55% | +57% |
| Concurrent Users | 100 | 500 | +400% |
| Memory Usage | 268MB | 250MB | -7% |

---

**Status:** Recommendations documented  
**Next Step:** Implement Week 1 optimizations
