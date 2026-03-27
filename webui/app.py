"""
ai-colab Web UI Backend v2.2 (Security Enhanced)
Flask-based API and web server for configuration management and monitoring
Improvements: WebSocket support, real-time updates, enhanced dashboard pages, rate limiting
"""

import os
import json
import subprocess
import logging
import shutil
import socket
import threading
import time
from datetime import datetime
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import toml
import jsonschema

# SECURITY: Import centralized logging
try:
    import sys
    sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts'))
    from logging_config import (
        get_logger,
        get_security_logger,
        get_api_logger,
        log_security_event,
        log_api_request,
        get_log_stats
    )
    LOGGING_AVAILABLE = True
except ImportError as e:
    LOGGING_AVAILABLE = False
    print(f"Warning: Centralized logging not available: {e}")

# SECURITY: Rate limiting
try:
    from flask_limiter import Limiter
    from flask_limiter.util import get_remote_address
    RATE_LIMIT_AVAILABLE = True
except ImportError:
    RATE_LIMIT_AVAILABLE = False
    logger.warning("flask-limiter not installed. Install with: pip install flask-limiter")

# Configure logging
if LOGGING_AVAILABLE:
    logger = get_logger('ai_colab.webui')
    security_logger = get_security_logger()
    api_logger = get_api_logger()
else:
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    security_logger = logger
    api_logger = logger

# App configuration
APP_DIR = Path(__file__).parent.parent
CONFIG_DIR = APP_DIR / "config"
CONFIG_FILE = CONFIG_DIR / "config.toml"
CONFIG_SCHEMA = CONFIG_DIR / "config.schema.json"
STATE_FILE = APP_DIR / ".ai-colab-state.json"
SCRIPTS_DIR = APP_DIR / "scripts"
LOGS_DIR = APP_DIR / "logs"

# Configuration constants
MIN_DISK_SPACE_MB = 100
SESSION_LOCK = "/tmp/hcom-dashboard.lock"

# Create Flask app
def create_app():
    app = Flask(__name__,
                static_folder='static',
                static_url_path='')

    # Enable CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # SECURITY: Initialize rate limiter
    if RATE_LIMIT_AVAILABLE:
        limiter = Limiter(
            app=app,
            key_func=get_remote_address,
            default_limits=["100 per minute", "1000 per hour"],
            storage_uri="memory://"
        )
        logger.info("Rate limiting enabled: 100 req/min, 1000 req/hour")
    else:
        limiter = None
        logger.warning("Rate limiting disabled (flask-limiter not installed)")

    # Initialize SocketIO for real-time updates
    socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

    # Add request logging middleware
    @app.before_request
    def log_request():
        """Log all API requests for monitoring and debugging"""
        request.start_time = time.time()
        
        # Skip logging for static files
        if request.path.startswith('/static') or request.path == '/':
            return None
        
        client_ip = request.remote_addr
        logger.debug(f"Request: {request.method} {request.path} from {client_ip}")
        
        # Log security events for sensitive endpoints
        if request.path.startswith('/api/'):
            # Check for suspicious patterns
            if '..' in request.path or request.path.count('/') > 10:
                log_security_event('SUSPICIOUS_PATH', f'{request.method} {request.path}', client_ip)
        
        return None
    
    @app.after_request
    def log_response(response):
        """Log response status and duration"""
        if hasattr(request, 'start_time'):
            duration_ms = (time.time() - request.start_time) * 1000
        else:
            duration_ms = 0
        
        # Skip logging for static files
        if request.path.startswith('/static') or request.path == '/':
            return response
        
        client_ip = request.remote_addr
        
        # Log API requests
        if request.path.startswith('/api/'):
            log_api_request(
                request.method,
                request.path,
                response.status_code,
                duration_ms,
                client_ip
            )
        
        # Log errors and warnings
        if response.status_code >= 500:
            logger.error(f"Server error: {request.method} {request.path} -> {response.status_code}")
        elif response.status_code >= 400:
            logger.warning(f"Client error: {request.method} {request.path} -> {response.status_code}")
        else:
            logger.debug(f"Success: {request.method} {request.path} -> {response.status_code} ({duration_ms:.2f}ms)")
        
        return response

    # Register routes
    register_routes(app, socketio, limiter)

    # Start background thread for real-time updates
    start_realtime_updates(socketio)

    return app


def register_routes(app, socketio, limiter=None):

    # WebSocket event handlers
    @socketio.on('connect')
    def handle_connect():
        logger.info('Client connected to WebSocket')
        emit('connected', {'message': 'Connected to ai-colab Web UI'})

    @socketio.on('disconnect')
    def handle_disconnect():
        logger.info('Client disconnected from WebSocket')

    @socketio.on('subscribe_status')
    def handle_subscribe():
        logger.info('Client subscribed to status updates')

    @app.route('/')
    def index():
        """Serve the main HTML page"""
        return send_from_directory(APP_DIR / 'webui', 'index.html')

    @app.route('/<path:filename>')
    def static_files(filename):
        """Serve static files"""
        return send_from_directory(APP_DIR / 'webui', filename)

    @app.route('/health')
    def health():
        """Enhanced health check endpoint with comprehensive system status"""
        try:
            # Import health monitor
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from health_monitor import get_health_monitor
            
            monitor = get_health_monitor()
            health_data = monitor.get_health(force_refresh=True)
            
            # Determine status code
            status_code = 200 if health_data.status == 'healthy' else 503
            
            # Log health status
            if health_data.status != 'healthy':
                logger.warning(f"Health check: {health_data.status}")
                for name, status in health_data.components.items():
                    if status.status != 'healthy':
                        logger.warning(f"  {name}: {status.status} - {status.message}")
            
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
            # Fallback to basic health check
            return jsonify({
                'status': 'degraded',
                'message': 'Health monitor not available',
                'error': str(e)
            }), 503
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.route('/health/detailed')
    def health_detailed():
        """Detailed health check with all metrics"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from health_monitor import get_health_monitor
            
            monitor = get_health_monitor()
            return jsonify(json.loads(monitor.get_health_json(force_refresh=True)))
            
        except Exception as e:
            logger.error(f"Detailed health check failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.route('/health/logs')
    def health_logs():
        """Get log statistics and recent entries"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from logging_config import get_log_stats, LOG_DIR
            
            stats = get_log_stats()
            
            # Get recent error entries
            error_log = LOG_DIR / 'error.log'
            recent_errors = []
            
            if error_log.exists():
                with open(error_log, 'r') as f:
                    lines = f.readlines()
                    recent_errors = lines[-50:]  # Last 50 errors
            
            stats['recent_errors'] = recent_errors
            stats['log_directory'] = str(LOG_DIR)
            
            return jsonify(stats)
            
        except Exception as e:
            logger.error(f"Log stats failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500

    @app.route('/metrics', methods=['GET'])
    def metrics_endpoint():
        """Export metrics in Prometheus or JSON format"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from metrics import get_metrics_registry
            
            registry = get_metrics_registry()
            format_type = request.args.get('format', 'json').lower()
            
            if format_type == 'prometheus':
                # Export in Prometheus text format
                metrics_text = registry.to_prometheus()
                return Response(
                    metrics_text,
                    mimetype='text/plain',
                    headers={
                        'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'
                    }
                )
            else:
                # Export as JSON
                metrics_dict = registry.get_metrics()
                return jsonify(metrics_dict)
                
        except ImportError as e:
            logger.error(f"Metrics not available: {e}")
            return jsonify({
                'status': 'error',
                'error': 'Metrics system not initialized'
            }), 503
        except Exception as e:
            logger.error(f"Metrics export failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500

    @app.route('/metrics/export')
    def export_metrics_file():
        """Export metrics as downloadable file"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from metrics import get_metrics_registry
            
            registry = get_metrics_registry()
            format_type = request.args.get('format', 'json').lower()
            
            if format_type == 'prometheus':
                metrics_text = registry.to_prometheus()
                return Response(
                    metrics_text,
                    mimetype='text/plain',
                    headers={
                        'Content-Disposition': 'attachment; filename=ai-colab-metrics.prom',
                        'Content-Type': 'text/plain; version=0.0.4; charset=utf-8'
                    }
                )
            else:
                metrics_dict = registry.get_metrics()
                return jsonify(metrics_dict)
                
        except Exception as e:
            logger.error(f"Metrics export failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500

    # ========================================================================
    # Inference Gateway API Endpoints
    # ========================================================================
    
    @app.route('/api/inference/v1/complete', methods=['POST'])
    async def inference_complete():
        """Execute inference request"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from inference import get_gateway
            
            gateway = get_gateway()
            data = request.json
            
            if not data or not data.get('prompt'):
                return jsonify({
                    'status': 'error',
                    'error': 'Prompt is required'
                }), 400
            
            # Execute inference
            response = await gateway.complete(**data)
            
            return jsonify({
                'request_id': response.request_id,
                'status': response.status,
                'response': response.response,
                'model_used': response.model_used,
                'tokens_used': response.tokens_used,
                'latency_ms': response.latency_ms,
                'cached': response.cached,
                'cost_usd': response.cost_usd
            })
            
        except Exception as e:
            logger.error(f"Inference request failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.route('/api/inference/v1/batch', methods=['POST'])
    async def inference_batch():
        """Execute batch inference requests"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from inference import get_gateway
            
            gateway = get_gateway()
            data = request.json
            
            if not data or not data.get('requests'):
                return jsonify({
                    'status': 'error',
                    'error': 'Requests array is required'
                }), 400
            
            # Execute batch requests in parallel
            import asyncio
            tasks = [
                gateway.complete(**req)
                for req in data['requests']
            ]
            
            responses = await asyncio.gather(*tasks, return_exceptions=True)
            
            results = []
            for i, response in enumerate(responses):
                if isinstance(response, Exception):
                    results.append({
                        'request_id': data['requests'][i].get('request_id', f'batch_{i}'),
                        'status': 'error',
                        'error': str(response)
                    })
                else:
                    results.append({
                        'request_id': response.request_id,
                        'status': response.status,
                        'response': response.response,
                        'model_used': response.model_used,
                        'tokens_used': response.tokens_used,
                        'latency_ms': response.latency_ms
                    })
            
            return jsonify({
                'batch_id': f"batch_{int(time.time())}",
                'results': results,
                'total_requests': len(results),
                'successful': sum(1 for r in results if r['status'] == 'success')
            })
            
        except Exception as e:
            logger.error(f"Batch inference failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.route('/api/inference/v1/metrics', methods=['GET'])
    def inference_metrics():
        """Get inference metrics"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from inference import get_gateway
            
            gateway = get_gateway()
            metrics = gateway.get_metrics()
            
            return jsonify(metrics)
            
        except Exception as e:
            logger.error(f"Metrics request failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    
    @app.route('/api/inference/v1/models', methods=['GET'])
    def inference_models():
        """Get available models and their status"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from inference import get_gateway
            
            gateway = get_gateway()
            models = gateway.get_model_status()
            
            return jsonify({
                'models': [
                    {
                        'id': model_id,
                        'name': info['name'],
                        'status': info['status'],
                        'avg_latency_ms': info['avg_latency_ms'],
                        'request_count': info['request_count'],
                        'total_tokens': info['total_tokens']
                    }
                    for model_id, info in models.items()
                ]
            })
            
        except Exception as e:
            logger.error(f"Models request failed: {e}")
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500

    # ========================================================================
    # Model Registry API Endpoints
    # ========================================================================
    
    @app.route('/api/models', methods=['GET'])
    def list_models():
        """List all registered models"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            models = registry.list_models()
            
            return jsonify({'models': models})
            
        except Exception as e:
            logger.error(f"List models failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models/<model_id>', methods=['GET'])
    def get_model(model_id):
        """Get model information"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            model = registry.get_model(model_id)
            
            if model:
                return jsonify({'model': model})
            else:
                return jsonify({'status': 'error', 'error': 'Model not found'}), 404
            
        except Exception as e:
            logger.error(f"Get model failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models', methods=['POST'])
    def register_model():
        """Register a new model"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry, ModelType
            
            registry = get_registry()
            data = request.json
            
            model_type = ModelType(data.get('model_type', 'chat'))
            
            success = registry.register_model(
                model_id=data['id'],
                name=data['name'],
                provider=data['provider'],
                model_type=model_type,
                description=data.get('description', '')
            )
            
            if success:
                return jsonify({'status': 'success', 'message': 'Model registered'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to register model'}), 500
            
        except Exception as e:
            logger.error(f"Register model failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models/<model_id>/versions', methods=['GET'])
    def list_model_versions(model_id):
        """List all versions of a model"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            versions = registry.list_versions(model_id)
            
            return jsonify({
                'versions': [v.to_dict() for v in versions]
            })
            
        except Exception as e:
            logger.error(f"List versions failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models/<model_id>/active', methods=['GET'])
    def get_active_version(model_id):
        """Get currently active version"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            version = registry.get_active_version(model_id)
            
            if version:
                return jsonify({'version': version.to_dict()})
            else:
                return jsonify({'status': 'error', 'error': 'No active version'}), 404
            
        except Exception as e:
            logger.error(f"Get active version failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models/<model_id>/deploy', methods=['POST'])
    def deploy_version(model_id):
        """Deploy a model version"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            data = request.json
            version = data.get('version')
            
            if not version:
                return jsonify({'status': 'error', 'error': 'Version required'}), 400
            
            success = registry.deploy_version(model_id, version)
            
            if success:
                return jsonify({'status': 'success', 'message': f'Deployed {model_id}:{version}'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to deploy'}), 500
            
        except Exception as e:
            logger.error(f"Deploy version failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/models/<model_id>/rollback', methods=['POST'])
    def rollback_version(model_id):
        """Rollback to previous version"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            success = registry.rollback_version(model_id)
            
            if success:
                return jsonify({'status': 'success', 'message': 'Rolled back to previous version'})
            else:
                return jsonify({'status': 'error', 'error': 'No previous version to rollback to'}), 404
            
        except Exception as e:
            logger.error(f"Rollback failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/ab-tests', methods=['GET'])
    def list_ab_tests():
        """List A/B tests"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            
            registry = get_registry()
            status = request.args.get('status')
            tests = registry.list_ab_tests(status)
            
            return jsonify({
                'tests': [
                    {
                        'test_id': t.test_id,
                        'name': t.name,
                        'model_a': t.model_a,
                        'model_b': t.model_b,
                        'traffic_split': t.traffic_split,
                        'status': t.status,
                        'created_at': t.created_at
                    }
                    for t in tests
                ]
            })
            
        except Exception as e:
            logger.error(f"List A/B tests failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/ab-tests', methods=['POST'])
    def create_ab_test():
        """Create a new A/B test"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry, ABTest
            
            registry = get_registry()
            data = request.json
            
            ab_test = ABTest(
                test_id=data['test_id'],
                name=data['name'],
                model_a=data['model_a'],
                model_b=data['model_b'],
                traffic_split=data.get('traffic_split', 0.5)
            )
            
            success = registry.create_ab_test(ab_test)
            
            if success:
                return jsonify({'status': 'success', 'message': 'A/B test created'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to create A/B test'}), 500
            
        except Exception as e:
            logger.error(f"Create A/B test failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/ab-tests/<test_id>/assign', methods=['GET'])
    def get_ab_assignment(test_id):
        """Get model assignment for A/B test"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from model_registry import get_registry
            import uuid
            
            registry = get_registry()
            request_id = request.args.get('request_id', str(uuid.uuid4()))
            
            assignment = registry.get_ab_test_assignment(test_id, request_id)
            
            if assignment:
                return jsonify({
                    'test_id': test_id,
                    'request_id': request_id,
                    'assigned_model': assignment
                })
            else:
                return jsonify({'status': 'error', 'error': 'Test not found or not running'}), 404
            
        except Exception as e:
            logger.error(f"Get A/B assignment failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500

    # ========================================================================
    # Agent Federation API Endpoints
    # ========================================================================
    
    @app.route('/api/agents', methods=['GET'])
    def list_agents():
        """List all agents"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            status = request.args.get('status')
            agents = federation.coordination.list_agents(status)
            
            return jsonify({
                'agents': [a.to_dict() for a in agents],
                'count': len(agents)
            })
            
        except Exception as e:
            logger.error(f"List agents failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/agents', methods=['POST'])
    def register_agent():
        """Register a new agent"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation, Agent, AgentRole
            
            federation = get_federation()
            data = request.json
            
            agent = Agent(
                agent_id=data['agent_id'],
                name=data['name'],
                role=AgentRole(data.get('role', 'worker')),
                capabilities=data.get('capabilities', []),
                expertise_areas=data.get('expertise_areas', [])
            )
            
            success = federation.coordination.register_agent(agent)
            
            if success:
                return jsonify({'status': 'success', 'message': 'Agent registered'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to register'}), 500
            
        except Exception as e:
            logger.error(f"Register agent failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/teams', methods=['GET'])
    def list_teams():
        """List all teams"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            teams = list(federation.coordination.teams.values())
            
            return jsonify({
                'teams': [t.to_dict() for t in teams],
                'count': len(teams)
            })
            
        except Exception as e:
            logger.error(f"List teams failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/teams', methods=['POST'])
    def create_team():
        """Create a new team"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            data = request.json
            
            success = federation.coordination.create_team(
                team_id=data['team_id'],
                name=data['name'],
                member_ids=data['members'],
                leader_id=data.get('leader')
            )
            
            if success:
                return jsonify({'status': 'success', 'message': 'Team created'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to create team'}), 500
            
        except Exception as e:
            logger.error(f"Create team failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/tasks', methods=['GET'])
    def list_tasks():
        """List all tasks"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            tasks = list(federation.coordination.tasks.values())
            
            return jsonify({
                'tasks': [t.to_dict() for t in tasks],
                'count': len(tasks)
            })
            
        except Exception as e:
            logger.error(f"List tasks failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/tasks', methods=['POST'])
    def create_task():
        """Create a new task"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation, Task, TaskStatus
            
            federation = get_federation()
            data = request.json
            
            task = Task(
                task_id=data['task_id'],
                title=data['title'],
                description=data['description'],
                status=TaskStatus(data.get('status', 'pending')),
                priority=data.get('priority', 5),
                dependencies=data.get('dependencies', []),
                requires_consensus=data.get('requires_consensus', False)
            )
            
            success = federation.coordination.create_task(task)
            
            if success:
                return jsonify({'status': 'success', 'message': 'Task created'})
            else:
                return jsonify({'status': 'error', 'error': 'Failed to create task'}), 500
            
        except Exception as e:
            logger.error(f"Create task failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/tasks/<task_id>/handoff', methods=['POST'])
    def create_handoff(task_id):
        """Create task handoff between agents"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            data = request.json
            
            handoff_id = federation.coordination.create_handoff(
                from_agent=data['from_agent'],
                to_agent=data['to_agent'],
                task_id=task_id,
                context=data.get('context', {})
            )
            
            if handoff_id:
                return jsonify({
                    'status': 'success',
                    'handoff_id': handoff_id
                })
            else:
                return jsonify({'status': 'error', 'error': 'Failed to create handoff'}), 500
            
        except Exception as e:
            logger.error(f"Create handoff failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/knowledge', methods=['GET'])
    def list_knowledge():
        """List knowledge artifacts"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation, KnowledgeType
            
            federation = get_federation()
            query = request.args.get('q', '')
            ktype = request.args.get('type')
            
            if ktype:
                ktype = KnowledgeType(ktype)
            
            artifacts = federation.learning.search_knowledge(query, ktype)
            
            return jsonify({
                'knowledge': [a.to_dict() for a in artifacts],
                'count': len(artifacts)
            })
            
        except Exception as e:
            logger.error(f"List knowledge failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/knowledge', methods=['POST'])
    def share_knowledge():
        """Share new knowledge artifact"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation, KnowledgeArtifact, KnowledgeType, SharingScope
            
            federation = get_federation()
            data = request.json
            
            artifact = KnowledgeArtifact(
                artifact_id=data.get('artifact_id', f"knowledge_{len(federation.learning.knowledge)}"),
                title=data['title'],
                knowledge_type=KnowledgeType(data.get('knowledge_type', 'skill')),
                content=data['content'],
                created_by=data.get('created_by', 'system'),
                scope=SharingScope(data.get('scope', 'project')),
                tags=data.get('tags', [])
            )
            
            artifact_id = federation.learning.share_knowledge(artifact)
            
            return jsonify({
                'status': 'success',
                'artifact_id': artifact_id
            })
            
        except Exception as e:
            logger.error(f"Share knowledge failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/lessons', methods=['GET'])
    def list_lessons():
        """List lessons learned"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            severity = request.args.get('severity')
            lessons = federation.learning.get_lessons(severity)
            
            # Search if query provided
            query = request.args.get('q')
            if query:
                lessons = federation.learning.search_lessons(query)
            
            return jsonify({
                'lessons': [l.to_dict() for l in lessons],
                'count': len(lessons)
            })
            
        except Exception as e:
            logger.error(f"List lessons failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/lessons', methods=['POST'])
    def record_lesson():
        """Record a lesson learned"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation, LessonLearned
            
            federation = get_federation()
            data = request.json
            
            lesson = LessonLearned(
                lesson_id=data.get('lesson_id', f"lesson_{len(federation.learning.lessons)}"),
                title=data['title'],
                task_id=data.get('task_id'),
                agent_id=data.get('agent_id', 'system'),
                description=data['description'],
                root_cause=data['root_cause'],
                solution=data['solution'],
                prevention=data['prevention'],
                severity=data.get('severity', 'medium')
            )
            
            lesson_id = federation.learning.record_lesson(lesson)
            
            return jsonify({
                'status': 'success',
                'lesson_id': lesson_id
            })
            
        except Exception as e:
            logger.error(f"Record lesson failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/optimizations', methods=['GET'])
    def list_optimizations():
        """List performance optimizations"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            component = request.args.get('component')
            opts = federation.learning.get_optimizations(component)
            
            return jsonify({
                'optimizations': [o.to_dict() for o in opts],
                'count': len(opts)
            })
            
        except Exception as e:
            logger.error(f"List optimizations failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500
    
    @app.route('/api/federation/sync', methods=['POST'])
    def sync_federation():
        """Synchronize agent knowledge"""
        try:
            sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
            from agent_federation import get_federation
            
            federation = get_federation()
            data = request.json
            
            sync_result = federation.learning.sync_knowledge(
                agent_id=data['agent_id']
            )
            
            return jsonify(sync_result)
            
        except Exception as e:
            logger.error(f"Federation sync failed: {e}")
            return jsonify({'status': 'error', 'error': str(e)}), 500

    @app.route('/api/preflight', methods=['GET'])
    def preflight_checks():
        """Comprehensive pre-flight checks (mirrors dashboard-launch.sh)"""
        results = {
            "passed": True,
            "errors": [],
            "warnings": [],
            "checks": []
        }

        # Check 1: tmux available
        tmux_available = shutil.which('tmux') is not None
        if not tmux_available:
            results["errors"].append({
                "check": "tmux",
                "message": "tmux is not installed",
                "resolution": "Install with: brew install tmux (macOS) or sudo apt-get install tmux (Linux)"
            })
            results["passed"] = False
        else:
            try:
                result = subprocess.run(['tmux', '-V'], capture_output=True, text=True, timeout=2)
                version = result.stdout.strip() if result.returncode == 0 else "unknown"
            except:
                version = "unknown"
            results["checks"].append({
                "name": "tmux",
                "status": "pass",
                "message": f"tmux is available ({version})"
            })

        # Check 2: hcom available
        hcom_available = shutil.which('hcom') is not None
        if not hcom_available:
            results["errors"].append({
                "check": "hcom",
                "message": "hcom is not installed",
                "resolution": "Run ./install.sh to install hcom"
            })
            results["passed"] = False
        else:
            results["checks"].append({
                "name": "hcom",
                "status": "pass",
                "message": "hcom is available"
            })

        # Check 3: Terminal size (via socket - approximate)
        results["checks"].append({
            "name": "terminal",
            "status": "pass",
            "message": "Terminal size check skipped (browser-based)"
        })

        # Check 4: PROJECT_ROOT exists
        if APP_DIR.exists():
            results["checks"].append({
                "name": "project_root",
                "status": "pass",
                "message": f"Project root found ({APP_DIR})"
            })
        else:
            results["warnings"].append({
                "check": "project_root",
                "message": "PROJECT_ROOT not set or doesn't exist"
            })

        # Check 5: Disk space
        try:
            stat = shutil.disk_usage(APP_DIR)
            disk_free_mb = stat.free / (1024 * 1024)
            if disk_free_mb < MIN_DISK_SPACE_MB:
                results["warnings"].append({
                    "check": "disk_space",
                    "message": f"Low disk space (< {MIN_DISK_SPACE_MB}MB free)",
                    "details": f"{disk_free_mb:.0f}MB available"
                })
            else:
                results["checks"].append({
                    "name": "disk_space",
                    "status": "pass",
                    "message": f"Disk space is adequate ({disk_free_mb:.0f}MB free)"
                })
        except Exception as e:
            results["warnings"].append({
                "check": "disk_space",
                "message": "Could not check disk space",
                "details": str(e)
            })

        # Check 6: Stale lock file
        if os.path.exists(SESSION_LOCK):
            try:
                lock_age = datetime.now().timestamp() - os.path.getmtime(SESSION_LOCK)
                if lock_age > 3600:  # > 1 hour
                    results["checks"].append({
                        "name": "lock_file",
                        "status": "pass",
                        "message": "Stale lock file detected and will be cleaned up"
                    })
                else:
                    results["warnings"].append({
                        "check": "lock_file",
                        "message": "Another dashboard instance may be starting"
                    })
            except:
                pass

        return jsonify(results)

    @app.route('/api/session/status', methods=['GET'])
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
                            "id": parts[0] if len(parts) > 0 else "",
                            "title": parts[1] if len(parts) > 1 else ""
                        })
            
            # Get window count
            result = subprocess.run(
                ['tmux', 'list-windows', '-t', 'hcom-dashboard', '-F', '#{window_id}'],
                capture_output=True,
                text=True,
                timeout=2
            )
            
            windows = len(result.stdout.strip().split('\n')) if result.returncode == 0 else 1
            
            return jsonify({
                "exists": True,
                "healthy": True,
                "panes": panes,
                "pane_count": len(panes),
                "window_count": windows,
                "session": "hcom-dashboard"
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({
                "exists": True,
                "healthy": False,
                "message": "Session check timed out"
            }), 500
        except Exception as e:
            logger.error(f"Session status check failed: {e}")
            return jsonify({
                "exists": False,
                "healthy": False,
                "error": str(e)
            }), 500

    @app.route('/api/session/recover', methods=['POST'])
    def recover_session():
        """Recover from crashed or orphaned session"""
        try:
            # Kill existing session if corrupted
            subprocess.run(
                ['tmux', 'kill-session', '-t', 'hcom-dashboard'],
                capture_output=True,
                timeout=5
            )
            
            # Remove lock file
            if os.path.exists(SESSION_LOCK):
                os.remove(SESSION_LOCK)
            
            # Clean up orphaned agent processes
            subprocess.run(
                ['pkill', '-f', 'agent-wrapper.sh.*hcom'],
                capture_output=True,
                timeout=2
            )
            
            return jsonify({
                "status": "success",
                "message": "Session recovery complete"
            })
            
        except Exception as e:
            logger.error(f"Session recovery failed: {e}")
            return jsonify({
                "status": "error",
                "error": str(e)
            }), 500

    @app.route('/api/agents', methods=['GET'])
    def get_agents():
        """Get list of active agents from hcom"""
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
                                "name": parts[0],
                                "status": parts[1] if len(parts) > 1 else "unknown",
                                "details": ' '.join(parts[2:]) if len(parts) > 2 else ""
                            })
            
            return jsonify({
                "agents": agents,
                "count": len(agents)
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({
                "agents": [],
                "error": "hcom command timed out"
            }), 500
        except Exception as e:
            logger.error(f"Get agents failed: {e}")
            return jsonify({
                "agents": [],
                "error": str(e)
            }), 500

    @app.route('/api/dashboard/launch', methods=['POST'])
    def launch_dashboard():
        """Launch the dashboard with specified configuration"""
        try:
            config = request.json or {}
            
            # Build command
            cmd = ['bash', str(SCRIPTS_DIR / 'dashboard-launch.sh')]
            
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
                cwd=str(APP_DIR)
            )
            
            return jsonify({
                "status": "started",
                "message": "Dashboard launch initiated"
            })
            
        except Exception as e:
            logger.error(f"Dashboard launch failed: {e}")
            return jsonify({
                "status": "error",
                "error": str(e)
            }), 500
    
    @app.route('/api/config', methods=['GET'])
    def get_config():
        """Get current configuration"""
        try:
            if not CONFIG_FILE.exists():
                return jsonify({"error": "Configuration not found"}), 404
            
            with open(CONFIG_FILE, 'r') as f:
                config = toml.load(f)
            
            return jsonify(config)
        except Exception as e:
            logger.error(f"Error reading config: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/config', methods=['PUT'])
    def update_config():
        """Update configuration"""
        try:
            new_config = request.json
            
            # Validate against schema if available
            if CONFIG_SCHEMA.exists():
                with open(CONFIG_SCHEMA, 'r') as f:
                    schema = json.load(f)
                jsonschema.validate(instance=new_config, schema=schema)
            
            # Convert to TOML and write
            config_content = toml.dumps(new_config)
            
            # Backup existing config
            if CONFIG_FILE.exists():
                backup_dir = CONFIG_DIR / "backups"
                backup_dir.mkdir(exist_ok=True)
                timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
                backup_file = backup_dir / f"config.{timestamp}.toml"
                import shutil
                shutil.copy(CONFIG_FILE, backup_file)
                logger.info(f"Backup created: {backup_file}")
            
            # Write new config
            with open(CONFIG_FILE, 'w') as f:
                f.write(config_content)
            
            # Update state
            update_state("config_changed", datetime.now().isoformat())
            
            logger.info("Configuration updated successfully")
            return jsonify({"status": "success", "message": "Configuration updated"})
            
        except jsonschema.ValidationError as e:
            logger.error(f"Validation error: {e}")
            return jsonify({"error": "Validation failed", "details": str(e)}), 400
        except Exception as e:
            logger.error(f"Error updating config: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/config/validate', methods=['POST'])
    def validate_config():
        """Validate configuration against schema"""
        try:
            config = request.json
            
            if CONFIG_SCHEMA.exists():
                with open(CONFIG_SCHEMA, 'r') as f:
                    schema = json.load(f)
                jsonschema.validate(instance=config, schema=schema)
                return jsonify({"valid": True})
            else:
                return jsonify({"valid": True, "warning": "Schema not found"})
                
        except jsonschema.ValidationError as e:
            return jsonify({"valid": False, "error": str(e)})
    
    @app.route('/api/status', methods=['GET'])
    def get_status():
        """Get system status"""
        try:
            status = {
                "installation": {"status": "unknown", "pathway": "unknown"},
                "agents": [],
                "timestamp": datetime.now().isoformat()
            }
            
            # Read state file
            if STATE_FILE.exists():
                with open(STATE_FILE, 'r') as f:
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
                    status["hcom"] = "connected"
                    # Parse agent list from output
                    lines = result.stdout.strip().split('\n')
                    for line in lines[1:]:  # Skip header
                        if line.strip():
                            parts = line.split()
                            if len(parts) >= 3:
                                status["agents"].append({
                                    "name": parts[0],
                                    "status": parts[1] if len(parts) > 1 else "unknown"
                                })
                else:
                    status["hcom"] = "disconnected"
            except (FileNotFoundError, subprocess.TimeoutExpired):
                status["hcom"] = "not_installed"
            
            return jsonify(status)
            
        except Exception as e:
            logger.error(f"Error getting status: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/install', methods=['POST'])
    def trigger_install():
        """Trigger installation process"""
        try:
            config = request.json or {}
            pathway = config.get("pathway", "cli")
            
            # Start installation script
            if pathway == "cli":
                install_script = SCRIPTS_DIR / "install-wizard.sh"
            else:
                install_script = SCRIPTS_DIR / "install.sh"
            
            if not install_script.exists():
                return jsonify({"error": "Install script not found"}), 404
            
            # Run installation in background
            subprocess.Popen(
                ["bash", str(install_script), "--auto"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(APP_DIR)
            )
            
            logger.info("Installation triggered")
            return jsonify({
                "status": "started",
                "message": "Installation process started"
            })
            
        except Exception as e:
            logger.error(f"Error triggering install: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/launch', methods=['POST'])
    def trigger_launch():
        """Launch dashboard or agents"""
        try:
            config = request.json or {}
            components = config.get("components", ["dashboard"])
            
            launch_script = APP_DIR / "launch.sh"
            
            if not launch_script.exists():
                return jsonify({"error": "Launch script not found"}), 404
            
            # Build launch command
            cmd = ["bash", str(launch_script)]
            
            # For now, just trigger dashboard
            # In production, this would parse components and add appropriate flags
            
            # Run in background
            subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(APP_DIR)
            )
            
            logger.info("Launch triggered")
            return jsonify({
                "status": "started",
                "message": f"Launching: {', '.join(components)}"
            })
            
        except Exception as e:
            logger.error(f"Error triggering launch: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/logs', methods=['GET'])
    def get_logs():
        """Get recent logs"""
        try:
            lines = request.args.get('lines', '100', type=int)
            log_file = APP_DIR / "logs" / "ai-colab.log"
            
            if not log_file.exists():
                return jsonify({"logs": [], "message": "No logs available"})
            
            # Read last N lines
            with open(log_file, 'r') as f:
                all_lines = f.readlines()
                recent_lines = all_lines[-lines:]
            
            return jsonify({
                "logs": [line.strip() for line in recent_lines]
            })
            
        except Exception as e:
            logger.error(f"Error getting logs: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles', methods=['GET'])
    def get_profiles():
        """Get available configuration profiles"""
        try:
            profiles_dir = CONFIG_DIR / "profiles"
            
            if not profiles_dir.exists():
                return jsonify({"profiles": []})
            
            profiles = []
            for profile_file in profiles_dir.glob("*.toml"):
                profile_name = profile_file.stem
                profiles.append({
                    "name": profile_name,
                    "path": str(profile_file)
                })
            
            return jsonify({"profiles": profiles})
            
        except Exception as e:
            logger.error(f"Error getting profiles: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles/<name>', methods=['GET'])
    def get_profile(name):
        """Get specific profile configuration"""
        try:
            profile_file = CONFIG_DIR / "profiles" / f"{name}.toml"
            
            if not profile_file.exists():
                return jsonify({"error": "Profile not found"}), 404
            
            with open(profile_file, 'r') as f:
                config = toml.load(f)
            
            return jsonify(config)
            
        except Exception as e:
            logger.error(f"Error getting profile: {e}")
            return jsonify({"error": str(e)}), 500
    
    @app.route('/api/profiles/<name>/apply', methods=['POST'])
    def apply_profile(name):
        """Apply a configuration profile"""
        try:
            # Use config-manager.sh to load profile
            config_manager = SCRIPTS_DIR / "config-manager.sh"
            
            if not config_manager.exists():
                return jsonify({"error": "Config manager not found"}), 404
            
            result = subprocess.run(
                ["bash", str(config_manager), "load-profile", name],
                capture_output=True,
                text=True,
                cwd=str(APP_DIR)
            )
            
            if result.returncode != 0:
                return jsonify({"error": result.stderr}), 400
            
            return jsonify({
                "status": "success",
                "message": f"Profile '{name}' applied"
            })
            
        except Exception as e:
            logger.error(f"Error applying profile: {e}")
            return jsonify({"error": str(e)}), 500

    # SECURITY: Rate-limited KB endpoints
    if limiter:
        @app.route('/api/kb/search', methods=['GET'])
        @limiter.limit("30 per minute")
        def kb_search():
            return _kb_search_impl()
    else:
        @app.route('/api/kb/search', methods=['GET'])
        def kb_search():
            return _kb_search_impl()
    
    def _kb_search_impl():
        """Search knowledge base using RAG"""
        try:
            query = request.args.get('query', '')
            top_k = request.args.get('top_k', '5', type=int)
            source = request.args.get('source', None)
            
            # SECURITY: Input validation
            if not query or not query.strip():
                return jsonify({"error": "Query parameter 'query' is required"}), 400
            
            # Validate query length (prevent DoS)
            if len(query) > 500:
                return jsonify({"error": "Query too long (max 500 characters)"}), 400
            
            # Validate top_k range
            if top_k < 1 or top_k > 50:
                return jsonify({"error": "top_k must be between 1 and 50"}), 400
            
            # Validate source pattern (prevent path traversal)
            if source:
                import re
                if not re.match(r'^[a-zA-Z0-9_\-*/.]+$', source):
                    return jsonify({"error": "Invalid source pattern"}), 400
                # Prevent path traversal
                if '..' in source or source.startswith('/'):
                    return jsonify({"error": "Invalid source pattern"}), 400

            # Import RAG client
            import sys
            sys.path.insert(0, str(APP_DIR))
            from rag.client import RAGClient

            client = RAGClient()

            # Build filters
            filters = None
            if source:
                filters = {'source': source}

            # Search
            results = client.search(query, top_k=top_k, filters=filters)

            # Format results
            formatted = []
            for result in results:
                formatted.append({
                    'doc': result.get('doc', 'unknown'),
                    'section': result.get('section', ''),
                    'score': result.get('score', 0.0),
                    'source': result.get('source', ''),
                    'excerpt': result.get('excerpt', '')[:500]
                })

            client.close()

            return jsonify(formatted)

        except ImportError as e:
            logger.error(f"RAG not available: {e}")
            return jsonify({
                "error": "RAG system not initialized. Install requirements-rag.txt"
            }), 503
        except Exception as e:
            logger.error(f"KB search error: {e}")
            return jsonify({"error": str(e)}), 500

    @app.route('/api/kb/index', methods=['POST'])
    def kb_index():
        """Trigger knowledge base indexing"""
        try:
            # SECURITY: Rate limit indexing (expensive operation)
            import time
            last_index = APP_DIR / ".last_index_time"
            if last_index.exists():
                try:
                    with open(last_index) as f:
                        last_time = float(f.read().strip())
                    if time.time() - last_time < 60:  # 1 minute cooldown
                        return jsonify({
                            "status": "error",
                            "error": "Please wait before re-indexing (1 minute cooldown)"
                        }), 429
                except (ValueError, IOError):
                    pass
            
            import sys
            sys.path.insert(0, str(APP_DIR))
            from rag.client import RAGClient

            client = RAGClient()
            result = client.index(force=False)
            client.close()
            
            # Record last index time
            with open(last_index, 'w') as f:
                f.write(str(time.time()))

            return jsonify(result)

        except ImportError as e:
            logger.error(f"RAG not available: {e}")
            return jsonify({
                "status": "error",
                "error": "RAG system not initialized"
            }), 503
        except Exception as e:
            logger.error(f"KB index error: {e}")
            return jsonify({"error": str(e)}), 500

    @app.route('/api/kb/stats', methods=['GET'])
    def kb_stats():
        """Get knowledge base statistics"""
        try:
            import sys
            sys.path.insert(0, str(APP_DIR))
            from rag.client import RAGClient
            
            client = RAGClient()
            
            if not client.index_path.exists():
                return jsonify({
                    "document_count": 0,
                    "message": "Index not found. Run indexing first."
                })
            
            stats = client.get_stats()
            client.close()
            
            return jsonify(stats)
            
        except ImportError as e:
            logger.error(f"RAG not available: {e}")
            return jsonify({
                "error": "RAG system not initialized"
            }), 503
        except Exception as e:
            logger.error(f"KB stats error: {e}")
            return jsonify({"error": str(e)}), 500


def update_state(key, value):
    """Update state file"""
    try:
        if not STATE_FILE.exists():
            state = {"version": "1.0.0", "created": datetime.now().isoformat()}
        else:
            with open(STATE_FILE, 'r') as f:
                state = json.load(f)

        # Update key (supports dot notation)
        keys = key.split('.')
        current = state
        for k in keys[:-1]:
            if k not in current:
                current[k] = {}
            current = current[k]
        current[keys[-1]] = value

        # Update timestamp
        state["last_modified"] = datetime.now().isoformat()

        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)

    except Exception as e:
        logger.error(f"Error updating state: {e}")


def start_realtime_updates(socketio):
    """Start background thread for real-time status updates via WebSocket"""
    def broadcast_updates():
        """Periodically broadcast system status updates"""
        while True:
            try:
                # Gather status data
                status_data = {
                    "timestamp": datetime.now().isoformat(),
                    "system": {},
                    "agents": [],
                    "session": {}
                }

                # Health check
                try:
                    tmux_available = shutil.which('tmux') is not None
                    hcom_available = shutil.which('hcom') is not None
                    stat = shutil.disk_usage(APP_DIR)
                    disk_free_mb = stat.free / (1024 * 1024)

                    status_data["system"] = {
                        "tmux": tmux_available,
                        "hcom": hcom_available,
                        "disk_free_mb": round(disk_free_mb, 1),
                        "healthy": tmux_available and hcom_available and disk_free_mb >= MIN_DISK_SPACE_MB
                    }
                except:
                    pass

                # Agent status
                try:
                    result = subprocess.run(
                        ['hcom', 'list'],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    if result.returncode == 0:
                        lines = result.stdout.strip().split('\n')
                        for line in lines[1:]:
                            if line.strip():
                                parts = line.split()
                                if len(parts) >= 2:
                                    status_data["agents"].append({
                                        "name": parts[0],
                                        "status": parts[1] if len(parts) > 1 else "unknown"
                                    })
                except:
                    pass

                # Session status
                try:
                    result = subprocess.run(
                        ['tmux', 'has-session', '-t', 'hcom-dashboard'],
                        capture_output=True,
                        timeout=2
                    )
                    status_data["session"]["active"] = result.returncode == 0
                except:
                    status_data["session"]["active"] = False

                # Broadcast to all connected clients
                socketio.emit('status_update', status_data)

            except Exception as e:
                logger.error(f"Real-time update error: {e}")

            # Wait 5 seconds before next update
            time.sleep(5)

    # Start background thread
    thread = threading.Thread(target=broadcast_updates, daemon=True)
    thread.start()
    logger.info("Real-time update thread started")


# Create app instance
app = create_app()

if __name__ == '__main__':
    logger.info("Starting ai-colab Web UI server...")
    app.run(host='0.0.0.0', port=8080, debug=False)
