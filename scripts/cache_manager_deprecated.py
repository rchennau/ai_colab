"""
ai-colab Cache Manager - DEPRECATED

This module is deprecated. Use scripts/utils_core.py::SimpleCache instead.

Reason: Duplicate functionality, utils_core has smart TTL and better performance.

Migration:
  OLD: from scripts.cache_manager import CacheManager
  NEW: from scripts.utils_core import SimpleCache, get_global_cache
"""

import warnings
from scripts.utils_core import SimpleCache, get_global_cache

# Show deprecation warning
warnings.warn(
    "scripts.cache_manager is deprecated. "
    "Use scripts.utils_core::SimpleCache instead.",
    DeprecationWarning,
    stacklevel=2
)

# Backward compatibility - redirect to new implementation
CacheManager = SimpleCache
get_cache_manager = get_global_cache

__all__ = ['CacheManager', 'get_cache_manager']
