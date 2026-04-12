"""
ai-colab Web UI Backend v3.0 (Refactored)
Flask-based API with modular blueprints for better maintainability.
"""

import os
import logging
from pathlib import Path
from flask import Flask, send_from_directory, request
from flask_cors import CORS
from flask_socketio import SocketIO

# SECURITY: Import centralized logging
try:
    import sys
    sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts'))
    from logging_config import get_logger, get_security_logger, get_api_logger
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
    logger.warning("flask-limiter not installed") if 'logger' in dir() else print("Warning: flask-limiter not installed")

# Configure logging
if LOGGING_AVAILABLE:
    logger = get_logger('ai_colab.webui')
    security_logger = get_security_logger()
    api_logger = get_api_logger()
else:
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)

# App configuration
WEBUI_DIR = Path(__file__).parent
PROJECT_ROOT = WEBUI_DIR.parent
APP_DIR = WEBUI_DIR  # Alias for compatibility with old code if needed

CONFIG_DIR = PROJECT_ROOT / "config"
CONFIG_FILE = CONFIG_DIR / "config.toml"
STATE_FILE = PROJECT_ROOT / ".ai-colab-state.json"
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
LOGS_DIR = PROJECT_ROOT / "logs"

# Configuration constants
MIN_DISK_SPACE_MB = 100
SESSION_LOCK = "/tmp/hcom-dashboard.lock"


def create_app():
    """Create and configure Flask app"""
    app = Flask(__name__, static_folder='static', static_url_path='')
    
    # Enable CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
    # Store PROJECT_ROOT in app config
    app.config['PROJECT_ROOT'] = PROJECT_ROOT
    
    # Initialize rate limiter
    if RATE_LIMIT_AVAILABLE:
        limiter = Limiter(
            app=app,
            key_func=get_remote_address,
            default_limits=["100 per minute", "1000 per hour"],
            storage_uri="memory://"
        )
        logger.info("Rate limiting enabled: 100 req/min, 1000 req/hour")
    
    # Initialize SocketIO
    socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')
    
    # Initialize PTY manager for web terminals
    from webui.api.terminal import PTYManager, init_terminal_events
    import webui.api.terminal as terminal_module
    terminal_module.pty_manager = PTYManager(socketio)
    init_terminal_events(socketio)
    logger.info("PTY manager and Socket.IO events initialized")

    # App-level Socket.IO Event Handlers
    @socketio.on('connect')
    def handle_connect():
        logger.info('Client connected to main WebSocket')
        from flask_socketio import emit
        emit('connected', {'message': 'Connected to ai-colab Web UI'})
    
    # Add request logging middleware
    @app.before_request
    def log_request():
        request.start_time = __import__('time').time()
        if request.path.startswith('/api/'):
            if '..' in request.path or request.path.count('/') > 10:
                from logging_config import log_security_event
                log_security_event('SUSPICIOUS_PATH', f'{request.method} {request.path}', request.remote_addr)
    
    @app.after_request
    def log_response(response):
        if hasattr(request, 'start_time') and not request.path.startswith('/static'):
            duration_ms = (__import__('time').time() - request.start_time) * 1000
            if request.path.startswith('/api/'):
                from logging_config import log_api_request
                log_api_request(request.method, request.path, response.status_code, duration_ms, request.remote_addr)
            if response.status_code >= 500:
                logger.error(f"Server error: {request.method} {request.path} -> {response.status_code}")
            elif response.status_code >= 400:
                logger.warning(f"Client error: {request.method} {request.path} -> {response.status_code}")
        return response
    
    # Register API blueprints
    from webui.api import (
        inference_bp, models_bp, federation_bp, 
        vision_bp, system_bp, terminal_bp, config_bp,
        conductor_bp, kb_bp
    )
    app.register_blueprint(inference_bp)
    app.register_blueprint(models_bp)
    app.register_blueprint(federation_bp)
    app.register_blueprint(vision_bp)
    app.register_blueprint(system_bp)
    app.register_blueprint(terminal_bp)
    app.register_blueprint(config_bp)
    app.register_blueprint(conductor_bp)
    app.register_blueprint(kb_bp)
    
    # Serve main HTML page
    @app.route('/')
    def index():
        return send_from_directory(APP_DIR, 'index.html')

    @app.route('/health')
    def health_redirect():
        # Delegate to the system blueprint's health function
        from webui.api.system import health
        return health()
    
    @app.route('/<path:filename>')
    def static_files(filename):
        return send_from_directory(APP_DIR, filename)
    
    logger.info("Web UI app created with modular blueprints")
    
    return app


# Create app instance
app = create_app()


if __name__ == '__main__':
    logger.info("Starting ai-colab Web UI server...")
    app.run(host='0.0.0.0', port=8080, debug=False)
