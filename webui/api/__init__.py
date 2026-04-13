"""
Web UI API Blueprints
Split from monolithic app.py for better maintainability.
"""

from .inference import inference_bp
from .models import models_bp
from .federation import federation_bp
from .vision import vision_bp
from .system import system_bp
from .terminal import terminal_bp
from .config import config_bp
from .conductor import conductor_bp
from .kb import kb_bp
from .analytics import analytics_bp
from .insights import insights_bp

__all__ = [
    'inference_bp',
    'models_bp',
    'federation_bp',
    'vision_bp',
    'system_bp',
    'terminal_bp',
    'config_bp',
    'conductor_bp',
    'kb_bp',
    'analytics_bp',
    'insights_bp'
]
