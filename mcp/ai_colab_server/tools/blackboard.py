"""
Blackboard tools for MCP server.
Provides get/set access to the shared blackboard (KV store).
"""

import subprocess
import json
import logging
from datetime import datetime
from typing import Any, Optional

logger = logging.getLogger(__name__)

from ..server import server


@server.tool()
async def blackboard_get(key: str) -> dict:
    """
    Retrieve a value from the shared blackboard (KV store).
    
    Args:
        key: The blackboard key to query
        
    Returns:
        dict: {'key': str, 'value': any, 'timestamp': str, 'status': str}
    """
    try:
        # Use hcom-kv to get the value
        result = subprocess.run(
            ['hcom-kv', 'get', key],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            try:
                value = json.loads(result.stdout.strip())
            except json.JSONDecodeError:
                value = result.stdout.strip()
            
            return {
                'key': key,
                'value': value,
                'timestamp': datetime.now().isoformat(),
                'status': 'success'
            }
        else:
            return {
                'key': key,
                'value': None,
                'timestamp': datetime.now().isoformat(),
                'status': 'not_found',
                'error': result.stderr.strip()
            }
            
    except subprocess.TimeoutExpired:
        logger.error(f"blackboard_get timeout for key: {key}")
        return {
            'key': key,
            'value': None,
            'timestamp': datetime.now().isoformat(),
            'status': 'error',
            'error': 'Timeout'
        }
    except FileNotFoundError:
        logger.error("hcom-kv not found")
        return {
            'key': key,
            'value': None,
            'timestamp': datetime.now().isoformat(),
            'status': 'error',
            'error': 'hcom-kv not installed'
        }
    except Exception as e:
        logger.error(f"blackboard_get error: {e}")
        return {
            'key': key,
            'value': None,
            'timestamp': datetime.now().isoformat(),
            'status': 'error',
            'error': str(e)
        }


@server.tool()
async def blackboard_set(key: str, value: Any, ttl: int = 3600) -> dict:
    """
    Set a value in the shared blackboard.
    
    Args:
        key: The blackboard key
        value: The value to store (JSON-serializable)
        ttl: Time-to-live in seconds (default: 1 hour)
        
    Returns:
        dict: {'status': str, 'key': str, 'timestamp': str}
    """
    try:
        # Convert value to JSON string
        value_json = json.dumps(value)
        
        # Use hcom-kv to set the value with TTL
        result = subprocess.run(
            ['hcom-kv', 'set', key, value_json, '--ttl', str(ttl)],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            return {
                'status': 'success',
                'key': key,
                'timestamp': datetime.now().isoformat()
            }
        else:
            return {
                'status': 'error',
                'key': key,
                'timestamp': datetime.now().isoformat(),
                'error': result.stderr.strip()
            }
            
    except subprocess.TimeoutExpired:
        logger.error(f"blackboard_set timeout for key: {key}")
        return {
            'status': 'error',
            'key': key,
            'timestamp': datetime.now().isoformat(),
            'error': 'Timeout'
        }
    except FileNotFoundError:
        logger.error("hcom-kv not found")
        return {
            'status': 'error',
            'key': key,
            'timestamp': datetime.now().isoformat(),
            'error': 'hcom-kv not installed'
        }
    except Exception as e:
        logger.error(f"blackboard_set error: {e}")
        return {
            'status': 'error',
            'key': key,
            'timestamp': datetime.now().isoformat(),
            'error': str(e)
        }
