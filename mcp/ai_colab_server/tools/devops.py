"""
DevOps tools for MCP server.
Provides git sync, build trigger, and health check capabilities.
"""

import subprocess
import logging
import shutil
from pathlib import Path
from datetime import datetime

logger = logging.getLogger(__name__)

from ..server import server

PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
SCRIPTS_DIR = PROJECT_ROOT / "scripts"


@server.tool()
async def git_sync(branch: str = None) -> dict:
    """
    Synchronize with git repository.
    
    Args:
        branch: Optional branch name (default: current branch)
        
    Returns:
        dict: {'status': str, 'branch': str, 'commit': str}
    """
    try:
        # Get current branch if not specified
        if not branch:
            result = subprocess.run(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                capture_output=True,
                text=True,
                cwd=PROJECT_ROOT,
                timeout=5
            )
            if result.returncode == 0:
                branch = result.stdout.strip()
            else:
                branch = 'unknown'
        
        # Pull latest changes
        result = subprocess.run(
            ['git', 'pull'],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=30
        )
        
        # Get current commit
        result = subprocess.run(
            ['git', 'rev-parse', '--short', 'HEAD'],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=5
        )
        commit = result.stdout.strip() if result.returncode == 0 else 'unknown'
        
        return {
            'status': 'success',
            'branch': branch,
            'commit': commit,
            'timestamp': datetime.now().isoformat()
        }
        
    except subprocess.TimeoutExpired:
        logger.error("git_sync timeout")
        return {
            'status': 'error',
            'error': 'Timeout',
            'branch': branch or 'unknown',
            'commit': 'unknown'
        }
    except Exception as e:
        logger.error(f"git_sync error: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'branch': branch or 'unknown',
            'commit': 'unknown'
        }


@server.tool()
async def build_trigger(target: str = 'all') -> dict:
    """
    Trigger a project build.
    
    Args:
        target: Build target (default: 'all')
        
    Returns:
        dict: {'status': str, 'build_id': str, 'logs': str}
    """
    try:
        logger.info(f"build_trigger called with target: {target}")
        
        # Check for build script
        build_script = SCRIPTS_DIR / "build.sh"
        
        if not build_script.exists():
            # Try make
            if shutil.which('make'):
                result = subprocess.run(
                    ['make', target],
                    capture_output=True,
                    text=True,
                    cwd=PROJECT_ROOT,
                    timeout=60
                )
                return {
                    'status': 'completed' if result.returncode == 0 else 'failed',
                    'build_id': f"build_{int(datetime.now().timestamp())}",
                    'logs': result.stdout + result.stderr,
                    'exit_code': result.returncode
                }
            else:
                return {
                    'status': 'error',
                    'error': 'No build script or make found',
                    'build_id': None,
                    'logs': ''
                }
        
        # Run build script
        result = subprocess.run(
            ['bash', str(build_script), target],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=120
        )
        
        return {
            'status': 'completed' if result.returncode == 0 else 'failed',
            'build_id': f"build_{int(datetime.now().timestamp())}",
            'logs': result.stdout + result.stderr,
            'exit_code': result.returncode
        }
        
    except subprocess.TimeoutExpired:
        logger.error("build_trigger timeout")
        return {
            'status': 'timeout',
            'error': 'Build timed out',
            'build_id': f"build_{int(datetime.now().timestamp())}",
            'logs': 'Build timed out after 120 seconds'
        }
    except Exception as e:
        logger.error(f"build_trigger error: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'build_id': None,
            'logs': ''
        }


@server.tool()
async def health_check() -> dict:
    """
    Check system health status.
    
    Returns:
        dict: {'status': str, 'checks': dict}
    """
    try:
        checks = {}
        issues = []
        
        # Check tmux
        tmux_available = shutil.which('tmux') is not None
        checks['tmux'] = {
            'available': tmux_available,
            'status': 'pass' if tmux_available else 'fail'
        }
        if not tmux_available:
            issues.append('tmux not installed')
        
        # Check hcom
        hcom_available = shutil.which('hcom') is not None
        checks['hcom'] = {
            'available': hcom_available,
            'status': 'pass' if hcom_available else 'fail'
        }
        if not hcom_available:
            issues.append('hcom not installed')
        
        # Check disk space
        try:
            stat = shutil.disk_usage(PROJECT_ROOT)
            disk_free_mb = stat.free / (1024 * 1024)
            min_disk_mb = 100
            disk_ok = disk_free_mb >= min_disk_mb
            checks['disk'] = {
                'free_mb': round(disk_free_mb, 1),
                'minimum_mb': min_disk_mb,
                'status': 'pass' if disk_ok else 'warning'
            }
            if not disk_ok:
                issues.append(f'low disk space ({disk_free_mb:.0f}MB)')
        except Exception as e:
            checks['disk'] = {
                'status': 'error',
                'error': str(e)
            }
            issues.append('could not check disk space')
        
        # Check MCP server
        checks['mcp_server'] = {
            'status': 'pass',
            'message': 'MCP server running'
        }
        
        # Determine overall health
        overall_status = 'healthy' if not issues else 'unhealthy'
        
        return {
            'status': overall_status,
            'checks': checks,
            'issues': issues,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"health_check error: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'checks': {},
            'issues': [str(e)]
        }
