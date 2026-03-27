"""
ai-colab Core Utilities
Consolidated utility functions to reduce code duplication.
"""

import hashlib
import json
import logging
import os
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger('ai_colab.utils')


# ============================================================================
# Cache Utilities (Consolidated from cache_manager.py, rag/search/cache.py)
# ============================================================================

class SimpleCache:
    """
    Unified in-memory cache with TTL support.
    
    Replaces duplicate cache implementations across:
    - scripts/cache_manager.py
    - rag/search/cache.py
    - scripts/health_monitor.py
    """
    
    def __init__(self, max_size: int = 10000, default_ttl: int = 300):
        self.max_size = max_size
        self.default_ttl = default_ttl
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.Lock()
        self._hits = 0
        self._misses = 0
        
        logger.info(f"SimpleCache initialized (max_size={max_size}, ttl={default_ttl}s)")
    
    def _make_key(self, key: str, namespace: str = None) -> str:
        """Create namespaced cache key"""
        if namespace:
            return f"{namespace}:{key}"
        return key
    
    def _is_expired(self, entry: Dict[str, Any]) -> bool:
        """Check if cache entry is expired"""
        if 'expires_at' not in entry:
            return False
        return datetime.now() > entry['expires_at']
    
    def _evict_if_needed(self):
        """Evict oldest entries if cache is full"""
        if len(self._cache) < self.max_size:
            return
        
        # Sort by access time, remove oldest 10%
        sorted_keys = sorted(
            self._cache.keys(),
            key=lambda k: self._cache[k].get('accessed_at', datetime.min)
        )
        
        remove_count = max(1, self.max_size // 10)
        for key in sorted_keys[:remove_count]:
            del self._cache[key]
    
    def get(self, key: str, namespace: str = None) -> Any:
        """Get value from cache"""
        with self._lock:
            full_key = self._make_key(key, namespace)
            
            if full_key not in self._cache:
                self._misses += 1
                return None
            
            entry = self._cache[full_key]
            
            if self._is_expired(entry):
                del self._cache[full_key]
                self._misses += 1
                return None
            
            entry['accessed_at'] = datetime.now()
            self._hits += 1
            return entry['value']
    
    def set(self, key: str, value: Any, ttl: int = None,
            namespace: str = None) -> bool:
        """Set value in cache"""
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
                entry['expires_at'] = datetime.now() + \
                    __import__('datetime').timedelta(seconds=ttl)
            
            self._cache[full_key] = entry
            return True
    
    def delete(self, key: str, namespace: str = None) -> bool:
        """Delete key from cache"""
        with self._lock:
            full_key = self._make_key(key, namespace)
            
            if full_key in self._cache:
                del self._cache[full_key]
                return True
            return False
    
    def exists(self, key: str, namespace: str = None) -> bool:
        """Check if key exists"""
        with self._lock:
            full_key = self._make_key(key, namespace)
            return full_key in self._cache
    
    def clear(self, namespace: str = None) -> bool:
        """Clear cache (optionally by namespace)"""
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
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        with self._lock:
            total = self._hits + self._misses
            hit_rate = (self._hits / total * 100) if total > 0 else 0.0
            
            return {
                'keys_count': len(self._cache),
                'max_size': self.max_size,
                'hits': self._hits,
                'misses': self._misses,
                'hit_rate': round(hit_rate, 2),
                'utilization': round(len(self._cache) / self.max_size * 100, 2)
            }


# ============================================================================
# Error Handling Utilities (Standardized)
# ============================================================================

class AIColabError(Exception):
    """Base exception for ai-colab"""
    def __init__(self, message: str, code: str = None):
        self.message = message
        self.code = code or self.__class__.__name__
        super().__init__(self.message)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'error': self.code,
            'message': self.message
        }


class ConfigurationError(AIColabError):
    """Configuration-related errors"""
    pass


class ModelNotFoundError(AIColabError):
    """Model not found errors"""
    pass


class InferenceError(AIColabError):
    """Inference-related errors"""
    pass


class ValidationError(AIColabError):
    """Input validation errors"""
    pass


class CacheError(AIColabError):
    """Cache-related errors"""
    pass


def handle_exception(e: Exception, logger=None) -> Dict[str, Any]:
    """
    Standardized exception handling.
    
    Returns dict suitable for API responses.
    """
    if logger:
        logger.error(f"Error: {e}")
    
    if isinstance(e, AIColabError):
        return e.to_dict()
    
    return {
        'error': type(e).__name__,
        'message': str(e)
    }


# ============================================================================
# File Utilities (Consolidated)
# ============================================================================

def ensure_dir(path: str) -> Path:
    """Ensure directory exists"""
    p = Path(path)
    p.mkdir(parents=True, exist_ok=True)
    return p


def secure_write(path: str, content: str, mode: int = 0o600) -> bool:
    """
    Write file with secure permissions.
    
    Args:
        path: File path
        content: File content
        mode: File permissions (default: 600 = owner read/write only)
    
    Returns:
        True if successful
    """
    try:
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        
        # Write to temp file first
        temp_path = p.with_suffix(p.suffix + '.tmp')
        with open(temp_path, 'w') as f:
            f.write(content)
        
        # Set permissions before moving
        os.chmod(temp_path, mode)
        
        # Atomic rename
        temp_path.rename(p)
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to write {path}: {e}")
        return False


def safe_json_load(path: str, default: Any = None) -> Any:
    """Safely load JSON file"""
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def safe_json_dump(path: str, data: Any, **kwargs) -> bool:
    """Safely dump JSON file"""
    try:
        return secure_write(path, json.dumps(data, **kwargs))
    except Exception as e:
        logger.error(f"Failed to write JSON {path}: {e}")
        return False


# ============================================================================
# Hash Utilities (Consolidated)
# ============================================================================

def hash_string(s: str, algorithm: str = 'md5') -> str:
    """
    Hash a string.
    
    Args:
        s: String to hash
        algorithm: Hash algorithm (md5, sha1, sha256)
    
    Returns:
        Hex digest string
    """
    if algorithm == 'md5':
        return hashlib.md5(s.encode()).hexdigest()
    elif algorithm == 'sha1':
        return hashlib.sha1(s.encode()).hexdigest()
    elif algorithm == 'sha256':
        return hashlib.sha256(s.encode()).hexdigest()
    else:
        raise ValueError(f"Unknown algorithm: {algorithm}")


def hash_file(path: str, algorithm: str = 'sha256') -> Optional[str]:
    """
    Hash a file.
    
    Args:
        path: File path
        algorithm: Hash algorithm
    
    Returns:
        Hex digest string or None if error
    """
    try:
        hasher = hashlib.new(algorithm)
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception as e:
        logger.error(f"Failed to hash {path}: {e}")
        return None


# ============================================================================
# Time Utilities (Consolidated)
# ============================================================================

def now_iso() -> str:
    """Get current time in ISO format"""
    return datetime.now().isoformat()


def parse_iso(s: str) -> datetime:
    """Parse ISO format string to datetime"""
    return datetime.fromisoformat(s)


def time_ago(dt: datetime) -> str:
    """
    Get human-readable time ago string.
    
    Args:
        dt: Datetime to compare
    
    Returns:
        Human-readable string (e.g., "5 minutes ago")
    """
    now = datetime.now()
    diff = now - dt
    
    seconds = diff.total_seconds()
    
    if seconds < 60:
        return "just now"
    elif seconds < 3600:
        return f"{int(seconds / 60)} minutes ago"
    elif seconds < 86400:
        return f"{int(seconds / 3600)} hours ago"
    else:
        return f"{int(seconds / 86400)} days ago"


# ============================================================================
# Singleton Pattern (Consolidated)
# ============================================================================

class SingletonMeta(type):
    """Metaclass for creating singletons"""
    _instances: Dict[type, Any] = {}
    _lock: threading.Lock = threading.Lock()
    
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            with cls._lock:
                if cls not in cls._instances:
                    cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]


# ============================================================================
# Global Cache Instance (Shared across modules)
# ============================================================================

_global_cache: Optional[SimpleCache] = None


def get_global_cache(max_size: int = 10000,
                    default_ttl: int = 300) -> SimpleCache:
    """
    Get or create global cache instance.
    
    This replaces duplicate cache managers across modules.
    
    Args:
        max_size: Maximum cache entries
        default_ttl: Default TTL in seconds
    
    Returns:
        SimpleCache instance
    """
    global _global_cache
    if _global_cache is None:
        _global_cache = SimpleCache(max_size, default_ttl)
    return _global_cache


# Convenience functions
def cache_get(key: str, namespace: str = None) -> Any:
    """Get from global cache"""
    return get_global_cache().get(key, namespace)


def cache_set(key: str, value: Any, ttl: int = None,
             namespace: str = None) -> bool:
    """Set in global cache"""
    return get_global_cache().set(key, value, ttl, namespace)


def cache_delete(key: str, namespace: str = None) -> bool:
    """Delete from global cache"""
    return get_global_cache().delete(key, namespace)


def cache_stats() -> Dict[str, Any]:
    """Get global cache statistics"""
    return get_global_cache().get_stats()
