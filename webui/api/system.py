"""
System API Blueprint (health, metrics, preflight)
"""

from flask import Blueprint, request, jsonify

system_bp = Blueprint('system', __name__, url_prefix='/api')


@system_bp.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    from webui.app import logger, PROJECT_ROOT
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from health_monitor import get_health_monitor
        monitor = get_health_monitor()
        health_data = monitor.get_health(force_refresh=True)
        
        status_code = 200 if health_data.status == 'healthy' else 503
        
        if health_data.status != 'healthy':
            logger.warning(f"Health check: {health_data.status}")
        
        return jsonify({
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
            }
        }), status_code
        
    except ImportError as e:
        logger.error(f"Health monitor not available: {e}")
        return jsonify({
            'status': 'degraded',
            'message': 'Health monitor not available',
            'error': str(e)
        }), 503
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/health/detailed', methods=['GET'])
def health_detailed():
    """Detailed health check"""
    from webui.app import logger, PROJECT_ROOT
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from health_monitor import get_health_monitor
        monitor = get_health_monitor()
        import json
        return jsonify(json.loads(monitor.get_health_json(force_refresh=True)))
    except Exception as e:
        logger.error(f"Detailed health check failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/health/logs', methods=['GET'])
def health_logs():
    """Get log statistics"""
    from webui.app import logger, PROJECT_ROOT
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
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
        logger.error(f"Log stats failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@system_bp.route('/preflight', methods=['GET'])
def preflight():
    """Pre-flight checks"""
    from webui.app import logger, PROJECT_ROOT
    import subprocess
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
    from webui.app import logger, PROJECT_ROOT
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from metrics import get_metrics_registry
        registry = get_metrics_registry()
        format_type = request.args.get('format', 'json').lower()
        
        if format_type == 'prometheus':
            metrics_text = registry.to_prometheus()
            from flask import Response
            return Response(metrics_text, mimetype='text/plain',
                          headers={'Content-Type': 'text/plain; version=0.0.4'})
        else:
            return jsonify(registry.get_metrics())
    except Exception as e:
        logger.error(f"Metrics request failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500
