"""
Tracks tools for MCP server.
Provides read/update access to project tracks (tracks.md).
"""

import subprocess
import json
import logging
import re
from pathlib import Path
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)

from ..server import server

# Project root (parent of mcp directory)
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
TRACKS_FILE = PROJECT_ROOT / "conductor" / "tracks.md"


@server.tool()
async def tracks_read() -> dict:
    """
    Read the current project tracks from tracks.md.
    
    Returns:
        dict: {'milestones': [...], 'tracks': [...], 'progress': {...}}
    """
    try:
        if not TRACKS_FILE.exists():
            return {
                'status': 'error',
                'error': 'tracks.md not found',
                'milestones': [],
                'tracks': [],
                'progress': {}
            }
        
        with open(TRACKS_FILE, 'r') as f:
            content = f.read()
        
        # Parse milestones
        milestones = []
        milestone_pattern = r'- \[([ x])\] \*\*Milestone \d+: ([^*]+)\*\* \(([^)]+)\)'
        for match in re.finditer(milestone_pattern, content):
            status_char, title, status = match.groups()
            milestones.append({
                'completed': status_char == 'x',
                'title': title.strip(),
                'status': status.strip()
            })
        
        # Parse tracks
        tracks = []
        track_pattern = r'- \[([ x~])\] \*\*Track: ([^*]+)\*\*(?:\n\s*-.*?)*?(?=\n- \[|\Z)'
        for match in re.finditer(track_pattern, content, re.DOTALL):
            status_char, title = match.groups()
            
            # Extract additional info from the track block
            track_content = match.group(0)
            assigned_match = re.search(r'\*\*Assigned:\*\* @(\w+)', track_content)
            desc_match = re.search(r'\*\*Description:\*\* (.+?)(?:\n|$)', track_content)
            
            status_map = {'x': 'completed', '~': 'in_progress', ' ': 'pending'}
            
            tracks.append({
                'status': status_map.get(status_char, 'unknown'),
                'title': title.strip(),
                'assigned': assigned_match.group(1) if assigned_match else None,
                'description': desc_match.group(1) if desc_match else None
            })
        
        # Calculate progress
        total_tracks = len(tracks)
        completed_tracks = sum(1 for t in tracks if t['status'] == 'completed')
        in_progress_tracks = sum(1 for t in tracks if t['status'] == 'in_progress')
        
        progress = {
            'total_tracks': total_tracks,
            'completed': completed_tracks,
            'in_progress': in_progress_tracks,
            'pending': total_tracks - completed_tracks - in_progress_tracks,
            'percentage': round(completed_tracks / total_tracks * 100, 1) if total_tracks > 0 else 0
        }
        
        return {
            'status': 'success',
            'milestones': milestones,
            'tracks': tracks,
            'progress': progress,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"tracks_read error: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'milestones': [],
            'tracks': [],
            'progress': {}
        }


@server.tool()
async def tracks_update(task_id: str, status: str, commit_sha: Optional[str] = None) -> dict:
    """
    Update a task status in tracks.md.
    
    Args:
        task_id: The task identifier (e.g., 'Phase 5.3' or task description)
        status: New status ('pending', 'in_progress', 'completed')
        commit_sha: Optional commit hash for completed tasks
        
    Returns:
        dict: {'status': str, 'updated_task': str, 'timestamp': str}
    """
    try:
        if not TRACKS_FILE.exists():
            return {
                'status': 'error',
                'error': 'tracks.md not found'
            }
        
        # Validate status
        status_map = {
            'pending': '[ ]',
            'in_progress': '[~]',
            'completed': '[x]'
        }
        
        if status not in status_map:
            return {
                'status': 'error',
                'error': f"Invalid status: {status}. Must be one of: pending, in_progress, completed"
            }
        
        new_status = status_map[status]
        
        with open(TRACKS_FILE, 'r') as f:
            content = f.read()
        
        # Try to find and update the task
        # Pattern 1: Match by phase/task ID (e.g., "Phase 5.3")
        pattern = rf'(\[.\]) \*\*Task.*?{re.escape(task_id)}.*?\*\*'
        match = re.search(pattern, content)
        
        if match:
            old_status = match.group(1)
            updated_content = content.replace(old_status, new_status, 1)
            
            # Add commit SHA if provided and status is completed
            if commit_sha and status == 'completed':
                # Find the task line and append commit SHA
                task_line_pattern = rf'({re.escape(task_id)}.*?)(\n)'
                updated_content = re.sub(
                    task_line_pattern,
                    rf'\1 [{commit_sha[:7]}]\2',
                    updated_content,
                    count=1
                )
            
            with open(TRACKS_FILE, 'w') as f:
                f.write(updated_content)
            
            logger.info(f"Updated task '{task_id}' to status '{status}'")
            
            return {
                'status': 'success',
                'updated_task': task_id,
                'new_status': status,
                'commit_sha': commit_sha[:7] if commit_sha else None,
                'timestamp': datetime.now().isoformat()
            }
        else:
            # Try pattern 2: Match by phase (e.g., "Phase 1:")
            phase_pattern = rf'(\[.\]) \*\*(Phase \d+: [^*]+)\*\*'
            match = re.search(phase_pattern, content)
            
            if match and task_id.lower() in match.group(2).lower():
                old_status = match.group(1)
                updated_content = content.replace(old_status, new_status, 1)
                
                with open(TRACKS_FILE, 'w') as f:
                    f.write(updated_content)
                
                logger.info(f"Updated phase '{task_id}' to status '{status}'")
                
                return {
                    'status': 'success',
                    'updated_task': task_id,
                    'new_status': status,
                    'timestamp': datetime.now().isoformat()
                }
        
        return {
            'status': 'error',
            'error': f"Task not found: {task_id}"
        }
        
    except Exception as e:
        logger.error(f"tracks_update error: {e}")
        return {
            'status': 'error',
            'error': str(e)
        }
