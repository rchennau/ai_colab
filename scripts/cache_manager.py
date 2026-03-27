"""
ai-colab Redis Cache Manager
Distributed caching with Redis for improved performance.
"""

import json
import logging
import hashlib
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

logger = logging.getLogger('ai_colab.redis_cache')

try:
    import redis
    import redis.asyncio as aioredis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    logger.warning("Redis not installed. Install with: pip install redis")


class RedisCache:
    """
    Redis-based distributed cache.
    
    Features:
    - TTL-based expiration
    - JSON serialization
    - Async support
    - Cache statistics
    - Key namespacing
    """
    
    def __init__(self, host: str = 'localhost', port: int = 6379,
                 db: int = 0, password: str = None,
                 max_memory_mb: int = 512, default_ttl: int = 300):
        """
        Initialize Redis cache.
        
        Args:
            host: Redis host
            port: Redis port
            db: Redis database number
            password: Redis password
            max_memory_mb: Max memory in MB
            default_ttl: Default TTL in seconds
        """
        self.host = host
        self.port = port
        self.db = db
        self.password = password
        self.default_ttl = default_ttl
        
        self._sync_client: Optional[redis.Redis] = None
        self._async_client: Optional[aioredis.Redis] = None
        
        if REDIS_AVAILABLE:
            self._init_sync_client()
        
        logger.info(f"RedisCache initialized: {host}:{port}")
    
    def _init_sync_client(self):
        """Initialize synchronous Redis client"""
        try:
            self._sync_client = redis.Redis(
                host=self.host,
                port=self.port,
                db=self.db,
                password=self.password,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            
            # Test connection
            self._sync_client.ping()
            logger.info("Redis connection established")
            
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self._sync_client = None
    
    async def _init_async_client(self):
        """Initialize asynchronous Redis client"""
        try:
            self._async_client = aioredis.Redis(
                host=self.host,
                port=self.port,
                db=self.db,
                password=self.password,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            
            await self._async_client.ping()
            logger.info("Async Redis connection established")
            
        except Exception as e:
            logger.error(f"Failed to connect to Redis (async): {e}")
            self._async_client = None
    
    def _make_key(self, key: str, namespace: str = None) -> str:
        """Create namespaced cache key"""
        if namespace:
            return f"{namespace}:{key}"
        return key
    
    def _serialize(self, value: Any) -> str:
        """Serialize value to JSON string"""
        return json.dumps(value, default=str)
    
    def _deserialize(self, value: str) -> Any:
        """Deserialize JSON string to value"""
        if value is None:
            return None
        return json.loads(value)
    
    # ========================================================================
    # Synchronous Operations
    # ========================================================================
    
    def get(self, key: str, namespace: str = None) -> Any:
        """Get value from cache"""
        if not self._sync_client:
            return None
        
        try:
            value = self._sync_client.get(self._make_key(key, namespace))
            return self._deserialize(value)
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None
    
    def set(self, key: str, value: Any, ttl: int = None,
            namespace: str = None) -> bool:
        """Set value in cache"""
        if not self._sync_client:
            return False
        
        try:
            ttl = ttl or self.default_ttl
            serialized = self._serialize(value)
            
            if ttl > 0:
                result = self._sync_client.setex(
                    self._make_key(key, namespace),
                    ttl,
                    serialized
                )
            else:
                result = self._sync_client.set(
                    self._make_key(key, namespace),
                    serialized
                )
            
            return bool(result)
            
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    def delete(self, key: str, namespace: str = None) -> bool:
        """Delete key from cache"""
        if not self._sync_client:
            return False
        
        try:
            result = self._sync_client.delete(self._make_key(key, namespace))
            return result > 0
        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False
    
    def exists(self, key: str, namespace: str = None) -> bool:
        """Check if key exists in cache"""
        if not self._sync_client:
            return False
        
        try:
            return self._sync_client.exists(self._make_key(key, namespace)) > 0
        except Exception as e:
            logger.error(f"Cache exists error: {e}")
            return False
    
    def get_ttl(self, key: str, namespace: str = None) -> int:
        """Get TTL for key"""
        if not self._sync_client:
            return -1
        
        try:
            return self._sync_client.ttl(self._make_key(key, namespace))
        except Exception as e:
            logger.error(f"Cache TTL error: {e}")
            return -1
    
    def increment(self, key: str, amount: int = 1, namespace: str = None) -> int:
        """Increment counter"""
        if not self._sync_client:
            return 0
        
        try:
            return self._sync_client.incr(
                self._make_key(key, namespace),
                amount
            )
        except Exception as e:
            logger.error(f"Cache increment error: {e}")
            return 0
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        if not self._sync_client:
            return {'connected': False}
        
        try:
            info = self._sync_client.info('memory')
            keys = self._sync_client.dbsize()
            
            return {
                'connected': True,
                'host': self.host,
                'port': self.port,
                'used_memory_mb': round(info.get('used_memory', 0) / 1024 / 1024, 2),
                'max_memory_mb': round(info.get('maxmemory', 0) / 1024 / 1024, 2),
                'keys_count': keys,
                'hit_rate': self._calculate_hit_rate()
            }
        except Exception as e:
            logger.error(f"Cache stats error: {e}")
            return {'connected': False, 'error': str(e)}
    
    def _calculate_hit_rate(self) -> float:
        """Calculate cache hit rate"""
        if not self._sync_client:
            return 0.0
        
        try:
            stats = self._sync_client.info('stats')
            hits = stats.get('keyspace_hits', 0)
            misses = stats.get('keyspace_misses', 0)
            total = hits + misses
            
            if total == 0:
                return 0.0
            
            return round(hits / total * 100, 2)
        except:
            return 0.0
    
    def flush(self, namespace: str = None) -> bool:
        """Flush cache (optionally by namespace)"""
        if not self._sync_client:
            return False
        
        try:
            if namespace:
                # Delete keys by pattern
                pattern = f"{namespace}:*"
                keys = self._sync_client.keys(pattern)
                if keys:
                    self._sync_client.delete(*keys)
            else:
                self._sync_client.flushdb()
            
            logger.info(f"Cache flushed: {namespace or 'all'}")
            return True
            
        except Exception as e:
            logger.error(f"Cache flush error: {e}")
            return False
    
    # ========================================================================
    # Asynchronous Operations
    # ========================================================================
    
    async def async_get(self, key: str, namespace: str = None) -> Any:
        """Get value from cache (async)"""
        if not self._async_client:
            if self._sync_client:
                await self._init_async_client()
            if not self._async_client:
                return None
        
        try:
            value = await self._async_client.get(self._make_key(key, namespace))
            return self._deserialize(value)
        except Exception as e:
            logger.error(f"Async cache get error: {e}")
            return None
    
    async def async_set(self, key: str, value: Any, ttl: int = None,
                       namespace: str = None) -> bool:
        """Set value in cache (async)"""
        if not self._async_client:
            if self._sync_client:
                await self._init_async_client()
            if not self._async_client:
                return False
        
        try:
            ttl = ttl or self.default_ttl
            serialized = self._serialize(value)
            
            if ttl > 0:
                result = await self._async_client.setex(
                    self._make_key(key, namespace),
                    ttl,
                    serialized
                )
            else:
                result = await self._async_client.set(
                    self._make_key(key, namespace),
                    serialized
                )
            
            return bool(result)
            
        except Exception as e:
            logger.error(f"Async cache set error: {e}")
            return False
    
    async def async_delete(self, key: str, namespace: str = None) -> bool:
        """Delete key from cache (async)"""
        if not self._async_client:
            return False
        
        try:
            result = await self._async_client.delete(
                self._make_key(key, namespace)
            )
            return result > 0
        except Exception as e:
            logger.error(f"Async cache delete error: {e}")
            return False
    
    async def async_exists(self, key: str, namespace: str = None) -> bool:
        """Check if key exists (async)"""
        if not self._async_client:
            return False
        
        try:
            exists = await self._async_client.exists(
                self._make_key(key, namespace)
            )
            return exists > 0
        except Exception as e:
            logger.error(f"Async cache exists error: {e}")
            return False
    
    async def async_increment(self, key: str, amount: int = 1,
                             namespace: str = None) -> int:
        """Increment counter (async)"""
        if not self._async_client:
            return 0
        
        try:
            return await self._async_client.incr(
                self._make_key(key, namespace),
                amount
            )
        except Exception as e:
            logger.error(f"Async cache increment error: {e}")
            return 0
    
    async def async_get_stats(self) -> Dict[str, Any]:
        """Get cache statistics (async)"""
        if not self._async_client:
            return {'connected': False}
        
        try:
            info = await self._async_client.info('memory')
            keys = await self._async_client.dbsize()
            
            return {
                'connected': True,
                'host': self.host,
                'port': self.port,
                'used_memory_mb': round(info.get('used_memory', 0) / 1024 / 1024, 2),
                'max_memory_mb': round(info.get('maxmemory', 0) / 1024 / 1024, 2),
                'keys_count': keys
            }
        except Exception as e:
            logger.error(f"Async cache stats error: {e}")
            return {'connected': False, 'error': str(e)}
    
    async def async_flush(self, namespace: str = None) -> bool:
        """Flush cache (async)"""
        if not self._async_client:
            return False
        
        try:
            if namespace:
                pattern = f"{namespace}:*"
                keys = await self._async_client.keys(pattern)
                if keys:
                    await self._async_client.delete(*keys)
            else:
                await self._async_client.flushdb()
            
            logger.info(f"Async cache flushed: {namespace or 'all'}")
            return True
            
        except Exception as e:
            logger.error(f"Async cache flush error: {e}")
            return False
    
    def close(self):
        """Close Redis connections"""
        if self._sync_client:
            self._sync_client.close()
            logger.info("Redis sync connection closed")
        
        if self._async_client:
            import asyncio
            asyncio.create_task(self._async_client.close())
            logger.info("Redis async connection closed")


# ============================================================================
# In-Memory Cache (Fallback)
# ============================================================================

class MemoryCache:
    """
    In-memory cache (fallback when Redis unavailable).
    
    Features:
    - TTL-based expiration
    - LRU eviction
    - Thread-safe
    """
    
    def __init__(self, max_size: int = 1000, default_ttl: int = 300):
        self.max_size = max_size
        self.default_ttl = default_ttl
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._lock = __import__('threading').Lock()
        logger.info(f"MemoryCache initialized (max_size={max_size})")
    
    def _make_key(self, key: str, namespace: str = None) -> str:
        if namespace:
            return f"{namespace}:{key}"
        return key
    
    def _is_expired(self, entry: Dict[str, Any]) -> bool:
        if 'expires_at' not in entry:
            return False
        return datetime.now() > entry['expires_at']
    
    def _evict_if_needed(self):
        """Evict oldest entries if cache is full"""
        if len(self._cache) < self.max_size:
            return
        
        # Sort by access time, remove oldest
        sorted_keys = sorted(
            self._cache.keys(),
            key=lambda k: self._cache[k].get('accessed_at', datetime.min)
        )
        
        # Remove oldest 10%
        remove_count = max(1, self.max_size // 10)
        for key in sorted_keys[:remove_count]:
            del self._cache[key]
    
    def get(self, key: str, namespace: str = None) -> Any:
        with self._lock:
            full_key = self._make_key(key, namespace)
            
            if full_key not in self._cache:
                return None
            
            entry = self._cache[full_key]
            
            if self._is_expired(entry):
                del self._cache[full_key]
                return None
            
            entry['accessed_at'] = datetime.now()
            return entry['value']
    
    def set(self, key: str, value: Any, ttl: int = None,
            namespace: str = None) -> bool:
        with self._lock:
            self._evict_if_needed()
            
            full_key = self._make_key(key, namespace)
            ttl = ttl or self.default_ttl
            
            entry = {
                'value': value,
                'created_at': datetime.now(),
                'accessed_at': datetime.now()
            }
            
            if ttl > 0:
                entry['expires_at'] = datetime.now() + timedelta(seconds=ttl)
            
            self._cache[full_key] = entry
            return True
    
    def delete(self, key: str, namespace: str = None) -> bool:
        with self._lock:
            full_key = self._make_key(key, namespace)
            
            if full_key in self._cache:
                del self._cache[full_key]
                return True
            return False
    
    def exists(self, key: str, namespace: str = None) -> bool:
        with self._lock:
            full_key = self._make_key(key, namespace)
            return full_key in self._cache
    
    def get_stats(self) -> Dict[str, Any]:
        with self._lock:
            now = datetime.now()
            total = len(self._cache)
            expired = sum(
                1 for entry in self._cache.values()
                if entry.get('expires_at') and entry['expires_at'] < now
            )
            
            return {
                'connected': True,
                'type': 'memory',
                'keys_count': total,
                'expired_count': expired,
                'max_size': self.max_size,
                'utilization': round(total / self.max_size * 100, 2)
            }
    
    def flush(self, namespace: str = None) -> bool:
        with self._lock:
            if namespace:
                pattern = f"{namespace}:"
                keys_to_delete = [
                    k for k in self._cache.keys()
                    if k.startswith(pattern)
                ]
                for key in keys_to_delete:
                    del self._cache[key]
            else:
                self._cache.clear()
            
            return True
    
    def close(self):
        """Close cache (no-op for memory cache)"""
        pass


# ============================================================================
# Cache Manager (Unified Interface)
# ============================================================================

class CacheManager:
    """
    Unified cache manager with Redis + Memory fallback.
    
    Automatically uses Redis if available, falls back to memory cache.
    """
    
    def __init__(self, redis_host: str = 'localhost', redis_port: int = 6379,
                 redis_db: int = 0, redis_password: str = None,
                 default_ttl: int = 300, max_memory_mb: int = 512):
        """
        Initialize cache manager.
        
        Args:
            redis_host: Redis host
            redis_port: Redis port
            redis_db: Redis database
            redis_password: Redis password
            default_ttl: Default TTL in seconds
            max_memory_mb: Max memory for memory cache
        """
        self.default_ttl = default_ttl
        
        # Try Redis first
        if REDIS_AVAILABLE:
            self._cache = RedisCache(
                host=redis_host,
                port=redis_port,
                db=redis_db,
                password=redis_password,
                max_memory_mb=max_memory_mb,
                default_ttl=default_ttl
            )
            self._type = 'redis'
        else:
            # Fallback to memory cache
            self._cache = MemoryCache(
                max_size=10000,
                default_ttl=default_ttl
            )
            self._type = 'memory'
        
        logger.info(f"CacheManager initialized: {self._type}")
    
    @property
    def cache_type(self) -> str:
        """Get cache type (redis or memory)"""
        return self._type
    
    def get(self, key: str, namespace: str = None) -> Any:
        """Get value from cache"""
        return self._cache.get(key, namespace)
    
    def set(self, key: str, value: Any, ttl: int = None,
            namespace: str = None) -> bool:
        """Set value in cache"""
        return self._cache.set(key, value, ttl or self.default_ttl, namespace)
    
    def delete(self, key: str, namespace: str = None) -> bool:
        """Delete key from cache"""
        return self._cache.delete(key, namespace)
    
    def exists(self, key: str, namespace: str = None) -> bool:
        """Check if key exists"""
        return self._cache.exists(key, namespace)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        return self._cache.get_stats()
    
    def flush(self, namespace: str = None) -> bool:
        """Flush cache"""
        return self._cache.flush(namespace)
    
    def close(self):
        """Close cache connections"""
        self._cache.close()


# Singleton instance
_cache_instance: Optional[CacheManager] = None


def get_cache_manager(redis_host: str = 'localhost', redis_port: int = 6379,
                     default_ttl: int = 300) -> CacheManager:
    """Get or create cache manager instance"""
    global _cache_instance
    if _cache_instance is None:
        _cache_instance = CacheManager(
            redis_host=redis_host,
            redis_port=redis_port,
            default_ttl=default_ttl
        )
    return _cache_instance
