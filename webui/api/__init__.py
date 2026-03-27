"""
Web UI API Blueprints
Split from monolithic app.py for better maintainability.
"""

from .inference import inference_bp
from .models import models_bp
from .federation import federation_bp
from .vision import vision_bp
from .system import system_bp

__all__ = [
    'inference_bp',
    'models_bp',
    'federation_bp',
    'vision_bp',
    'system_bp'
]
