"""
Query cache for RAG system.
Caches frequent search queries for faster response.
"""

import json
import logging
import time
from typing import Dict, Any, Optional, List
from pathlib import Path

logger = logging.getLogger(__name__)


class QueryCache:
    """
    In-memory query cache with TTL.
    
    Caches search results to reduce embedding and database queries.
    """
    
    def __init__(self, ttl: int = 3600, max_size: int = 1000):
        """
        Initialize query cache.
        
        Args:
            ttl: Time-to-live in seconds (default: 1 hour)
            max_size: Maximum cache entries
        """
        self.ttl = ttl
        self.max_size = max_size
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._hits = 0
        self._misses = 0
        
        logger.info(f"QueryCache initialized: TTL={ttl}s, max_size={max_size}")
    
    def get(self, key: str) -> Optional[Any]:
        """
        Get value from cache.
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found/expired
        """
        if key not in self._cache:
            self._misses += 1
            return None
        
        entry = self._cache[key]
        
        # Check expiration
        if time.time() - entry['timestamp'] > self.ttl:
            logger.debug(f"Cache entry expired: {key[:50]}...")
            del self._cache[key]
            self._misses += 1
            return None
        
        self._hits += 1
        logger.debug(f"Cache hit: {key[:50]}...")
        return entry['value']
    
    def set(self, key: str, value: Any):
        """
        Set value in cache.
        
        Args:
            key: Cache key
            value: Value to cache
        """
        # Evict oldest if at capacity
        if len(self._cache) >= self.max_size:
            self._evict_oldest()
        
        self._cache[key] = {
            'value': value,
            'timestamp': time.time(),
            'size': len(json.dumps(value)) if value else 0
        }
        
        logger.debug(f"Cache set: {key[:50]}...")
    
    def delete(self, key: str) -> bool:
        """Delete entry from cache."""
        if key in self._cache:
            del self._cache[key]
            return True
        return False
    
    def clear(self):
        """Clear all cache entries."""
        self._cache.clear()
        self._hits = 0
        self._misses = 0
        logger.info("Cache cleared")
    
    def _evict_oldest(self):
        """Evict oldest cache entry."""
        if not self._cache:
            return
        
        oldest_key = min(self._cache.keys(), 
                        key=lambda k: self._cache[k]['timestamp'])
        del self._cache[oldest_key]
        logger.debug(f"Evicted oldest entry: {oldest_key[:50]}...")
    
    def cleanup_expired(self) -> int:
        """Remove all expired entries. Returns count of removed entries."""
        now = time.time()
        expired = [k for k, v in self._cache.items() 
                  if now - v['timestamp'] > self.ttl]
        
        for key in expired:
            del self._cache[key]
        
        if expired:
            logger.info(f"Cleaned up {len(expired)} expired cache entries")
        
        return len(expired)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        total = self._hits + self._misses
        hit_rate = (self._hits / total * 100) if total > 0 else 0
        
        total_size = sum(entry.get('size', 0) for entry in self._cache.values())
        
        return {
            'entries': len(self._cache),
            'max_size': self.max_size,
            'hits': self._hits,
            'misses': self._misses,
            'hit_rate_percent': round(hit_rate, 2),
            'total_size_bytes': total_size,
            'total_size_kb': round(total_size / 1024, 2),
            'ttl_seconds': self.ttl
        }
    
    def get_cached_queries(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get most recently cached queries."""
        sorted_keys = sorted(
            self._cache.keys(),
            key=lambda k: self._cache[k]['timestamp'],
            reverse=True
        )[:limit]
        
        return [
            {
                'key': key[:100] + '...' if len(key) > 100 else key,
                'timestamp': self._cache[key]['timestamp'],
                'size': self._cache[key].get('size', 0)
            }
            for key in sorted_keys
        ]


# Global cache instance
_default_cache = None


def get_cache() -> QueryCache:
    """Get or create default cache."""
    global _default_cache
    if _default_cache is None:
        _default_cache = QueryCache()
    return _default_cache
