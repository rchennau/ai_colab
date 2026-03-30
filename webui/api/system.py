"""
System API Blueprint (health, metrics, preflight)
"""

import os
import sys
import subprocess
import json
from flask import Blueprint, request, jsonify, current_app, Response

system_bp = Blueprint('system', __name__, url_prefix='/api')


@system_bp.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        
        from health_monitor import get_health_monitor
        monitor = get_health_monitor()
        health_data = monitor.get_health(force_refresh=True)
        
        status_code = 200 if health_data.status == 'healthy' else 503
        
        if health_data.status != 'healthy':
            current_app.logger.warning(f"Health check: {health_data.status}")
        
        health_dict = {
            'status': health_data.status,
            'timestamp': health_data.timestamp,
            'uptime_seconds': health_data.uptime_seconds,
            'version': health_data.version,
            'components': {
                name: {
                    'status': status.status,
                    'message': status.message,
                    'details': status.details
                }
                for name, status in health_data.components.items()
            },
            'checks': {
                name: {
                    'status': status.status,
                    'message': status.message
                }
                for name, status in health_data.components.items()
            }
        }
        
        # Add disk alias if system exists for backward compatibility
        if 'system' in health_dict['checks']:
            health_dict['checks']['disk'] = health_dict['checks']['system']
        
        return jsonify(health_dict), status_code
        
    except ImportError as e:
        current_app.logger.error(f"Health monitor not available: {e}")
        return jsonify({
            'status': 'degraded',
            'message': 'Health monitor not available',
            'error': str(e)
        }), 503
    except Exception as e:
        current_app.logger.error(f"Health check failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/health/detailed', methods=['GET'])
def health_detailed():
    """Detailed health check"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from health_monitor import get_health_monitor
        monitor = get_health_monitor()
        return jsonify(json.loads(monitor.get_health_json(force_refresh=True)))
    except Exception as e:
        current_app.logger.error(f"Detailed health check failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/health/logs', methods=['GET'])
def health_logs():
    """Get log statistics"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from logging_config import get_log_stats, LOG_DIR
        stats = get_log_stats()
        
        error_log = LOG_DIR / 'error.log'
        recent_errors = []
        if error_log.exists():
            with open(error_log, 'r') as f:
                lines = f.readlines()
                recent_errors = lines[-50:]
        
        stats['recent_errors'] = recent_errors
        stats['log_directory'] = str(LOG_DIR)
        return jsonify(stats)
    except Exception as e:
        current_app.logger.error(f"Log stats failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/preflight', methods=['GET'])
def preflight():
    """Pre-flight checks"""
    results = {"passed": True, "errors": [], "warnings": [], "checks": []}
    
    # Check tmux
    tmux_available = subprocess.run(['which', 'tmux'], capture_output=True).returncode == 0
    if not tmux_available:
        results["errors"].append({"check": "tmux", "message": "tmux not installed",
                                 "resolution": "Install with: brew install tmux"})
        results["passed"] = False
    else:
        results["checks"].append({"name": "tmux", "status": "pass", "message": "tmux available"})
    
    # Check hcom
    hcom_available = subprocess.run(['which', 'hcom'], capture_output=True).returncode == 0
    if not hcom_available:
        results["errors"].append({"check": "hcom", "message": "hcom not installed",
                                 "resolution": "Run ./install.sh"})
        results["passed"] = False
    else:
        results["checks"].append({"name": "hcom", "status": "pass", "message": "hcom available"})
    
    return jsonify(results)


@system_bp.route('/metrics', methods=['GET'])
def metrics():
    """Get system metrics"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
            
        from metrics import get_metrics_registry
        registry = get_metrics_registry()
        format_type = request.args.get('format', 'json').lower()
        
        if format_type == 'prometheus':
            metrics_text = registry.to_prometheus()
            return Response(metrics_text, mimetype='text/plain',
                          headers={'Content-Type': 'text/plain; version=0.0.4'})
        else:
            return jsonify(registry.get_metrics())
    except Exception as e:
        current_app.logger.error(f"Metrics request failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/session/status', methods=['GET'])
def session_status():
    """Get tmux session status and agent information"""
    try:
        # Check if session exists
        result = subprocess.run(
            ['tmux', 'has-session', '-t', 'hcom-dashboard'],
            capture_output=True,
            timeout=2
        )

        if result.returncode != 0:
            return jsonify({
                "exists": False,
                "healthy": False,
                "message": "Session not running"
            })

        # Get pane count
        result = subprocess.run(
            ['tmux', 'list-panes', '-t', 'hcom-dashboard', '-F', '#{pane_id} #{pane_title}'],
            capture_output=True,
            text=True,
            timeout=2
        )

        panes = []
        if result.returncode == 0:
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split(' ', 1)
                    panes.append({
                        "id": parts[0],
                        "title": parts[1] if len(parts) > 1 else "unknown"
                    })

        # Get window count
        result = subprocess.run(
            ['tmux', 'list-windows', '-t', 'hcom-dashboard', '-F', '#{window_id}'],
            capture_output=True,
            text=True,
            timeout=2
        )
        window_count = len(result.stdout.strip().split('\n')) if result.returncode == 0 else 0

        return jsonify({
            "exists": True,
            "healthy": True,
            "pane_count": len(panes),
            "window_count": window_count,
            "panes": panes
        })

    except Exception as e:
        current_app.logger.error(f"Session status failed: {e}")
        return jsonify({"error": str(e), "exists": False}), 500


@system_bp.route('/status', methods=['GET'])
def get_status():
    """Get system status"""
    project_root = current_app.config.get('PROJECT_ROOT')
    state_file = project_root / ".ai-colab-state.json"
    from datetime import datetime
    try:
        status = {
            "installation": {"status": "unknown", "pathway": "unknown"},
            "agents": [],
            "timestamp": datetime.now().isoformat()
        }

        # Read state file
        if state_file.exists():
            with open(state_file, 'r') as f:
                state = json.load(f)
                status["installation"] = state.get("installation", {})

        # Check hcom status if available
        try:
            result = subprocess.run(
                ["hcom", "list"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                for line in result.stdout.splitlines():
                    if "○" in line or "●" in line:
                        parts = line.split()
                        if len(parts) >= 2:
                            status["agents"].append({
                                "name": parts[0],
                                "status": parts[1]
                            })
        except:
            pass

        return jsonify(status)

    except Exception as e:
        current_app.logger.error(f"Status failed: {e}")
        return jsonify({"error": str(e)}), 500


@system_bp.route('/dashboard/launch', methods=['POST'])
def launch_dashboard():
    """Launch the dashboard with specified configuration"""
    project_root = current_app.config.get('PROJECT_ROOT')
    scripts_dir = project_root / 'scripts'
    try:
        config = request.json or {}

        # Build command
        cmd = ['bash', str(scripts_dir / 'dashboard-launch.sh')]

        # Add flags based on config
        if config.get('conductor'):
            cmd.append('--conductor')
        if config.get('vllm'):
            cmd.append('--vllm')
        if config.get('claude'):
            cmd.append('--add-claude')
        if config.get('deepseek'):
            cmd.append('--add-deepseek')
        if config.get('bridge'):
            cmd.append('--bridge')

        # Launch in background
        subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=str(project_root)
        )

        return jsonify({
            "status": "started",
            "message": "Launching dashboard...",
            "command": " ".join(cmd)
        })

    except Exception as e:
        current_app.logger.error(f"Dashboard launch failed: {e}")
        return jsonify({"error": str(e)}), 500

