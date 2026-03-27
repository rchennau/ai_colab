"""
ai-colab Security Headers & HTTPS Configuration
Production security hardening for Web UI.
"""

import logging
import os
from pathlib import Path
from flask import Flask, request, Response

logger = logging.getLogger('ai_colab.security')


# ============================================================================
# Security Headers
# ============================================================================

SECURITY_HEADERS = {
    # Prevent clickjacking attacks
    'X-Frame-Options': 'DENY',
    
    # Prevent MIME type sniffing
    'X-Content-Type-Options': 'nosniff',
    
    # Enable XSS filter
    'X-XSS-Protection': '1; mode=block',
    
    # Referrer policy
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    
    # Content Security Policy
    'Content-Security-Policy': (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' cdn.socket.io; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' ws: wss:; "
        "frame-ancestors 'none'"
    ),
    
    # Permissions Policy (formerly Feature-Policy)
    'Permissions-Policy': (
        'accelerometer=(), camera=(), geolocation=(), gyroscope=(), '
        'magnetometer=(), microphone=(), payment=(), usb=()'
    ),
    
    # HTTP Strict Transport Security (HSTS)
    # Only set this if HTTPS is enabled
    # 'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    
    # Cross-Origin policies
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cross-Origin-Resource-Policy': 'same-origin'
}


def add_security_headers(response: Response) -> Response:
    """Add security headers to response"""
    for header, value in SECURITY_HEADERS.items():
        # Skip HSTS if not HTTPS
        if header == 'Strict-Transport-Security':
            if not request.is_secure and not os.environ.get('FORCE_HTTPS'):
                continue
        
        response.headers[header] = value
    
    return response


def init_security_headers(app: Flask):
    """Initialize security headers for Flask app"""
    
    @app.after_request
    def apply_security_headers(response: Response) -> Response:
        """Apply security headers to all responses"""
        return add_security_headers(response)
    
    logger.info("Security headers initialized")


# ============================================================================
# HTTPS Enforcement
# ============================================================================

def enforce_https(app: Flask):
    """Redirect all HTTP requests to HTTPS"""
    
    @app.before_request
    def redirect_to_https():
        # Skip if already HTTPS
        if request.is_secure:
            return None
        
        # Skip if HTTPS not enforced
        if not os.environ.get('FORCE_HTTPS', 'false').lower() == 'true':
            return None
        
        # Redirect to HTTPS
        url = request.url.replace('http://', 'https://', 1)
        return Response(
            status=301,
            headers={'Location': url}
        )
    
    logger.info("HTTPS enforcement enabled")


# ============================================================================
# SSL/TLS Configuration
# ============================================================================

def get_ssl_config() -> dict:
    """Get SSL/TLS configuration"""
    return {
        # Minimum TLS version
        'SSL_MIN_VERSION': 'TLSv1.2',
        
        # Preferred cipher suites
        'SSL_CIPHERS': (
            'ECDHE-ECDSA-AES128-GCM-SHA256:'
            'ECDHE-RSA-AES128-GCM-SHA256:'
            'ECDHE-ECDSA-AES256-GCM-SHA384:'
            'ECDHE-RSA-AES256-GCM-SHA384:'
            'ECDHE-ECDSA-CHACHA20-POLY1305:'
            'ECDHE-RSA-CHACHA20-POLY1305:'
            'DHE-RSA-AES128-GCM-SHA256:'
            'DHE-RSA-AES256-GCM-SHA384'
        ),
        
        # HSTS max age (1 year)
        'HSTS_MAX_AGE': 31536000,
        
        # Include subdomains in HSTS
        'HSTS_INCLUDE_SUBDOMAINS': True,
        
        # Preload HSTS
        'HSTS_PRELOAD': False
    }


# ============================================================================
# Let's Encrypt SSL Setup Script
# ============================================================================

SSL_SETUP_SCRIPT = """#!/bin/bash
# ai-colab SSL Setup with Let's Encrypt
# Usage: ./scripts/ssl_setup.sh domain.com

set -e

DOMAIN="${1:-}"
EMAIL="${2:-admin@$DOMAIN}"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [email]"
    exit 1
fi

echo "Setting up SSL for $DOMAIN..."

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install certbot
    else
        sudo apt-get update
        sudo apt-get install -y certbot
    fi
fi

# Get certificate
echo "Requesting certificate from Let's Encrypt..."
sudo certbot certonly \
    --standalone \
    --preferred-challenges http \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

# Certificate locations
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

echo ""
echo "✓ SSL certificate installed!"
echo ""
echo "Certificate: $CERT_PATH"
echo "Private Key: $KEY_PATH"
echo ""
echo "To use with ai-colab Web UI:"
echo "  export SSL_CERT_FILE=$CERT_PATH"
echo "  export SSL_KEY_FILE=$KEY_PATH"
echo "  export FORCE_HTTPS=true"
echo "  python webui/app.py"
echo ""
echo "Auto-renewal is configured. Certificates renew every 90 days."
echo "Test renewal with: sudo certbot renew --dry-run"
"""


def create_ssl_setup_script(output_path: str = None):
    """Create SSL setup script"""
    if output_path is None:
        output_path = Path(__file__).parent.parent / 'scripts' / 'ssl_setup.sh'
    
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w') as f:
        f.write(SSL_SETUP_SCRIPT)
    
    # Make executable
    os.chmod(output_path, 0o755)
    
    logger.info(f"SSL setup script created: {output_path}")
    return output_path


# ============================================================================
# Security Audit Logging
# ============================================================================

def log_security_event(event_type: str, details: dict, request=None):
    """Log security-related events"""
    log_entry = {
        'timestamp': __import__('datetime').datetime.now().isoformat(),
        'event_type': event_type,
        'details': details,
        'ip': request.remote_addr if request else None,
        'user_agent': request.headers.get('User-Agent') if request else None
    }
    
    logger.warning(f"SECURITY: {event_type} - {log_entry}")
    
    # Write to security log
    security_log = Path.home() / '.ai-colab' / 'logs' / 'security.log'
    security_log.parent.mkdir(parents=True, exist_ok=True)
    
    import json
    with open(security_log, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')


# ============================================================================
# Rate Limiting Helper
# ============================================================================

def get_rate_limit_key(request) -> str:
    """Generate rate limit key based on request"""
    # Use IP address as key
    return f"rate_limit:{request.remote_addr}"


def check_rate_limit(cache, key: str, max_requests: int = 100,
                    window_seconds: int = 60) -> bool:
    """
    Check if rate limit exceeded.
    
    Returns True if request is allowed, False if rate limited.
    """
    current = cache.get(key)
    
    if current is None:
        # First request in window
        cache.set(key, 1, ttl=window_seconds)
        return True
    
    if current >= max_requests:
        # Rate limit exceeded
        return False
    
    # Increment counter
    cache.increment(key)
    return True


# ============================================================================
# Initialization
# ============================================================================

def init_security(app: Flask, enable_https: bool = False):
    """
    Initialize all security features.
    
    Args:
        app: Flask application
        enable_https: Force HTTPS redirect
    """
    # Add security headers
    init_security_headers(app)
    
    # Enable HTTPS enforcement if requested
    if enable_https or os.environ.get('FORCE_HTTPS', 'false').lower() == 'true':
        enforce_https(app)
    
    # Create SSL setup script
    create_ssl_setup_script()
    
    logger.info("Security initialization complete")


# ============================================================================
# Security Checklist
# ============================================================================

SECURITY_CHECKLIST = """
# ai-colab Security Checklist

## Production Deployment

### Required
- [ ] Enable HTTPS (SSL/TLS)
- [ ] Set FORCE_HTTPS=true
- [ ] Configure security headers
- [ ] Enable rate limiting
- [ ] Set up audit logging
- [ ] Configure firewall rules
- [ ] Update all dependencies
- [ ] Remove debug mode

### Recommended
- [ ] Enable HSTS
- [ ] Configure CSP (Content Security Policy)
- [ ] Set up WAF (Web Application Firewall)
- [ ] Enable DDoS protection
- [ ] Configure log aggregation
- [ ] Set up security monitoring
- [ ] Regular security audits
- [ ] Penetration testing

### SSL/TLS
- [ ] Obtain SSL certificate (Let's Encrypt)
- [ ] Configure TLS 1.2+ only
- [ ] Use strong cipher suites
- [ ] Enable certificate auto-renewal
- [ ] Test SSL configuration (SSL Labs)

### Access Control
- [ ] Enable API authentication
- [ ] Configure CORS properly
- [ ] Implement IP whitelisting (if needed)
- [ ] Set up admin access controls
- [ ] Enable session management

### Monitoring
- [ ] Enable security logging
- [ ] Set up alerting for suspicious activity
- [ ] Monitor failed login attempts
- [ ] Track API abuse patterns
- [ ] Review logs regularly
"""


def print_security_checklist():
    """Print security checklist"""
    print(SECURITY_CHECKLIST)
