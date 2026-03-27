"""
ai-colab Centralized Logging Configuration
Provides consistent logging across all Python components with levels, formatting, and rotation.
"""

import logging
import os
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler, TimedRotatingFileHandler
from datetime import datetime

# Log levels
LOG_LEVELS = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL
}

# Get log directory from environment or use default
LOG_DIR = Path(os.environ.get('AI_COLAB_LOG_DIR', Path.home() / '.ai-colab' / 'logs'))
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Log file paths
MAIN_LOG_FILE = LOG_DIR / 'ai-colab.log'
SECURITY_LOG_FILE = LOG_DIR / 'security.log'
API_LOG_FILE = LOG_DIR / 'api.log'
ERROR_LOG_FILE = LOG_DIR / 'error.log'

# Get log level from environment
LOG_LEVEL = LOG_LEVELS.get(
    os.environ.get('AI_COLAB_LOG_LEVEL', 'INFO').upper(),
    logging.INFO
)

# Log format
LOG_FORMAT = logging.Formatter(
    '[%(asctime)s] [%(levelname)s] [%(name)s] [%(process)d] %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S%z'
)

# Console format (with colors for better readability)
class ColoredConsoleHandler(logging.StreamHandler):
    """Console handler with color-coded log levels"""
    
    COLORS = {
        logging.DEBUG: '\033[0;36m',     # Cyan
        logging.INFO: '\033[0;32m',      # Green
        logging.WARNING: '\033[1;33m',   # Yellow
        logging.ERROR: '\033[0;31m',     # Red
        logging.CRITICAL: '\033[1;31m',  # Bold Red
    }
    
    def emit(self, record):
        try:
            msg = self.format(record)
            color = self.COLORS.get(record.levelno, '')
            reset = '\033[0m'
            
            if record.levelno >= logging.WARNING:
                stream = self.stream
            else:
                stream = self.stream
            
            stream.write(f'{color}{msg}{reset}\n')
            self.flush()
        except Exception:
            self.handleError(record)


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the specified name.
    
    Args:
        name: Logger name (usually __name__)
    
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    
    # Only configure if not already configured
    if not logger.handlers:
        logger.setLevel(LOG_LEVEL)
        
        # Console handler (with colors)
        console_handler = ColoredConsoleHandler()
        console_handler.setLevel(LOG_LEVEL)
        console_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(console_handler)
        
        # Main log file handler (rotating)
        file_handler = RotatingFileHandler(
            MAIN_LOG_FILE,
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5,
            encoding='utf-8'
        )
        file_handler.setLevel(LOG_LEVEL)
        file_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(file_handler)
        
        # Error log file handler (separate file for errors and above)
        error_handler = RotatingFileHandler(
            ERROR_LOG_FILE,
            maxBytes=10*1024*1024,
            backupCount=3,
            encoding='utf-8'
        )
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(error_handler)
    
    return logger


def get_security_logger() -> logging.Logger:
    """
    Get a dedicated security logger.
    Security events are always logged regardless of log level.
    
    Returns:
        Configured security logger
    """
    logger = logging.getLogger('ai_colab.security')
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)  # Always log security events
        
        # Security log file handler
        security_handler = RotatingFileHandler(
            SECURITY_LOG_FILE,
            maxBytes=10*1024*1024,
            backupCount=10,  # Keep more security logs
            encoding='utf-8'
        )
        security_handler.setLevel(logging.INFO)
        security_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(security_handler)
        
        # Also log to console
        console_handler = ColoredConsoleHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(console_handler)
    
    return logger


def get_api_logger() -> logging.Logger:
    """
    Get a dedicated API request logger.
    
    Returns:
        Configured API logger
    """
    logger = logging.getLogger('ai_colab.api')
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        
        # API log file handler (time-based rotation for easier analysis)
        api_handler = TimedRotatingFileHandler(
            API_LOG_FILE,
            when='midnight',
            interval=1,
            backupCount=30,  # Keep 30 days of API logs
            encoding='utf-8'
        )
        api_handler.setLevel(logging.INFO)
        api_handler.setFormatter(LOG_FORMAT)
        logger.addHandler(api_handler)
    
    return logger


def log_security_event(event_type: str, details: str, client_ip: str = None):
    """
    Log a security event.
    
    Args:
        event_type: Type of security event (e.g., 'AUTH_FAILURE', 'INVALID_INPUT')
        details: Event details
        client_ip: Client IP address (optional)
    """
    logger = get_security_logger()
    ip_info = f' from {client_ip}' if client_ip else ''
    logger.warning(f"SECURITY EVENT [{event_type}]: {details}{ip_info}")


def log_api_request(method: str, endpoint: str, status: int, duration_ms: float, client_ip: str = None):
    """
    Log an API request.
    
    Args:
        method: HTTP method (GET, POST, etc.)
        endpoint: API endpoint
        status: HTTP status code
        duration_ms: Request duration in milliseconds
        client_ip: Client IP address (optional)
    """
    logger = get_api_logger()
    ip_info = f' from {client_ip}' if client_ip else ''
    logger.info(f"API {method} {endpoint} -> {status} ({duration_ms:.2f}ms){ip_info}")


def get_log_stats() -> dict:
    """
    Get logging statistics.
    
    Returns:
        Dictionary with log statistics
    """
    import os
    
    stats = {
        'timestamp': datetime.now().isoformat(),
        'log_dir': str(LOG_DIR),
        'log_level': logging.getLevelName(LOG_LEVEL),
        'files': {}
    }
    
    # Get stats for each log file
    for log_file, log_type in [
        (MAIN_LOG_FILE, 'main'),
        (SECURITY_LOG_FILE, 'security'),
        (API_LOG_FILE, 'api'),
        (ERROR_LOG_FILE, 'error')
    ]:
        if log_file.exists():
            stats['files'][log_type] = {
                'path': str(log_file),
                'size_bytes': log_file.stat().st_size,
                'size_mb': round(log_file.stat().st_size / 1024 / 1024, 2),
                'lines': sum(1 for _ in open(log_file, 'r', encoding='utf-8', errors='ignore'))
            }
    
    return stats


def cleanup_old_logs(days: int = 30):
    """
    Clean up log files older than specified days.
    
    Args:
        days: Number of days to keep logs
    """
    import time
    
    cutoff_time = time.time() - (days * 24 * 60 * 60)
    cleaned_count = 0
    
    for log_file in LOG_DIR.glob('*.log.*'):
        if log_file.stat().st_mtime < cutoff_time:
            log_file.unlink()
            cleaned_count += 1
    
    if cleaned_count > 0:
        get_logger(__name__).info(f"Cleaned up {cleaned_count} old log files")
    
    return cleaned_count


# Initialize logging when module is imported
def init_logging():
    """Initialize logging system"""
    logger = get_logger('ai_colab')
    logger.info(f"Logging initialized (level: {logging.getLevelName(LOG_LEVEL)}, dir: {LOG_DIR})")
    
    # Log Python version and platform info
    import platform
    logger.debug(f"Python {platform.python_version()} on {platform.system()} {platform.release()}")


# Auto-initialize on import
init_logging()
