"""
Agent management tools for MCP server.
Provides agent spawning and coordination capabilities.
"""

import subprocess
import logging
from typing import Optional, Dict, Any
from pathlib import Path

logger = logging.getLogger(__name__)

from ..server import server

PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"


@server.tool()
async def agent_spawn(role: str, task: str, context: Optional[Dict[str, Any]] = None) -> dict:
    """
    Spawn a remote agent for a specific task.
    
    Args:
        role: Agent role (e.g., 'architect', 'developer', 'reviewer')
        task: Task description
        context: Optional context dictionary
        
    Returns:
        dict: {'agent_id': str, 'status': str, 'channel': str}
    """
    try:
        logger.info(f"agent_spawn called: role={role}, task={task[:50]}...")
        
        # TODO: Implement actual agent spawning via hcom
        # For now, return placeholder response
        
        return {
            'agent_id': f"agent_{role}_{id(task)}",
            'status': 'pending',
            'channel': f"hcom_{role}",
            'message': 'Agent spawning - implementation pending'
        }
        
    except Exception as e:
        logger.error(f"agent_spawn error: {e}")
        return {
            'agent_id': None,
            'status': 'error',
            'channel': None,
            'error': str(e)
        }


@server.tool()
async def agent_list() -> dict:
    """
    List all active agents.
    
    Returns:
        dict: {'agents': list, 'count': int}
    """
    try:
        result = subprocess.run(
            ['hcom', 'list'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        agents = []
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines[1:]:  # Skip header
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        agents.append({
                            'name': parts[0],
                            'status': parts[1] if len(parts) > 1 else 'unknown',
                            'details': ' '.join(parts[2:]) if len(parts) > 2 else ''
                        })
        
        return {
            'agents': agents,
            'count': len(agents),
            'status': 'success'
        }
        
    except Exception as e:
        logger.error(f"agent_list error: {e}")
        return {
            'agents': [],
            'count': 0,
            'status': 'error',
            'error': str(e)
        }
