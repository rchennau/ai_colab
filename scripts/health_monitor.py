#!/usr/bin/env python3
"""
ai-colab Health Monitoring System
Monitors system health, vLLM connectivity, agent status, and resource usage.
Provides health endpoints and alerting capabilities.
"""

import os
import sys
import json
import time
import subprocess
import shutil
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

# Import centralized logging
try:
    from scripts.logging_config import get_logger, log_security_event
    logger = get_logger('ai_colab.health')
except ImportError:
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)


@dataclass
class HealthStatus:
    """Health status data structure"""
    component: str
    status: str  # 'healthy', 'degraded', 'unhealthy'
    message: str
    timestamp: str
    details: Dict[str, Any]


@dataclass
class SystemHealth:
    """Overall system health"""
    status: str
    timestamp: str
    components: Dict[str, HealthStatus]
    uptime_seconds: float
    version: str


class HealthMonitor:
    """
    Comprehensive health monitoring for ai-colab.
    
    Monitors:
    - System resources (CPU, memory, disk)
    - Service availability (tmux, hcom, vLLM)
    - Agent status
    - API endpoints
    - Database connectivity
    """
    
    def __init__(self):
        self.start_time = time.time()
        self.version = "2.2.0"
        self.health_cache = None
        self.cache_ttl = 10  # Cache health for 10 seconds
        self.last_check = 0
        
        # Configuration
        self.vllm_host = os.environ.get('VLLM_HOST', '192.168.0.193')
        self.vllm_port = os.environ.get('VLLM_PORT', '8000')
        self.disk_threshold_mb = int(os.environ.get('DISK_THRESHOLD_MB', '100'))
        
    def check_system_resources(self) -> HealthStatus:
        """Check system resource usage"""
        issues = []
        details = {}
        
        # Check disk space
        try:
            stat = shutil.disk_usage(PROJECT_ROOT)
            disk_free_mb = stat.free / (1024 * 1024)
            details['disk_free_mb'] = round(disk_free_mb, 2)
            details['disk_total_mb'] = round(stat.total / (1024 * 1024), 2)
            details['disk_used_percent'] = round((1 - stat.free/stat.total) * 100, 2)
            
            if disk_free_mb < self.disk_threshold_mb:
                issues.append(f"Low disk space: {disk_free_mb:.0f}MB free")
        except Exception as e:
            issues.append(f"Could not check disk space: {e}")
        
        # Check memory (if available)
        try:
            import psutil
            mem = psutil.virtual_memory()
            details['memory_available_mb'] = round(mem.available / (1024 * 1024), 2)
            details['memory_used_percent'] = mem.percent
            
            if mem.percent > 90:
                issues.append(f"High memory usage: {mem.percent}%")
        except ImportError:
            details['memory_available_mb'] = 'N/A (psutil not installed)'
        
        # Check load average
        try:
            load_avg = os.getloadavg()
            details['load_average'] = {
                '1min': round(load_avg[0], 2),
                '5min': round(load_avg[1], 2),
                '15min': round(load_avg[2], 2)
            }
        except (OSError, AttributeError):
            details['load_average'] = 'N/A (not available on this system)'
        
        # Determine status
        if issues:
            status = 'degraded' if len(issues) == 1 else 'unhealthy'
            message = '; '.join(issues)
        else:
            status = 'healthy'
            message = 'All system resources within normal limits'
        
        return HealthStatus(
            component='system',
            status=status,
            message=message,
            timestamp=datetime.now().isoformat(),
            details=details
        )
    
    def check_tmux(self) -> HealthStatus:
        """Check tmux availability and session status"""
        details = {}
        
        # Check if tmux is installed
        tmux_path = shutil.which('tmux')
        if not tmux_path:
            return HealthStatus(
                component='tmux',
                status='unhealthy',
                message='tmux is not installed',
                timestamp=datetime.now().isoformat(),
                details={'installed': False}
            )
        
        details['installed'] = True
        details['path'] = tmux_path
        
        # Get tmux version
        try:
            result = subprocess.run(
                ['tmux', '-V'],
                capture_output=True,
                text=True,
                timeout=5
            )
            details['version'] = result.stdout.strip()
        except Exception as e:
            details['version'] = f'Unknown: {e}'
        
        # Check for active sessions
        try:
            result = subprocess.run(
                ['tmux', 'list-sessions'],
                capture_output=True,
                text=True,
                timeout=5
            )
            sessions = [line.split(':')[0] for line in result.stdout.strip().split('\n') if line]
            details['active_sessions'] = sessions
            details['session_count'] = len(sessions)
        except Exception as e:
            details['active_sessions'] = []
            details['session_count'] = 0
        
        return HealthStatus(
            component='tmux',
            status='healthy',
            message=f'tmux available with {details["session_count"]} active session(s)',
            timestamp=datetime.now().isoformat(),
            details=details
        )
    
    def check_hcom(self) -> HealthStatus:
        """Check hcom availability and status"""
        details = {}
        
        # Check if hcom is installed
        hcom_path = shutil.which('hcom')
        if not hcom_path:
            return HealthStatus(
                component='hcom',
                status='unhealthy',
                message='hcom is not installed',
                timestamp=datetime.now().isoformat(),
                details={'installed': False}
            )
        
        details['installed'] = True
        details['path'] = hcom_path
        
        # Get hcom version
        try:
            result = subprocess.run(
                ['hcom', '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            details['version'] = result.stdout.strip()
        except Exception as e:
            details['version'] = f'Unknown: {e}'
        
        # Check hcom status
        try:
            result = subprocess.run(
                ['hcom', 'list'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            # Parse agent list
            agents = []
            lines = result.stdout.strip().split('\n')
            for line in lines[1:]:  # Skip header
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        agents.append({
                            'name': parts[0],
                            'status': parts[1]
                        })
            
            details['agents'] = agents
            details['agent_count'] = len(agents)
        except Exception as e:
            details['agents'] = []
            details['agent_count'] = 0
            details['error'] = str(e)
        
        return HealthStatus(
            component='hcom',
            status='healthy',
            message=f'hcom available with {details["agent_count"]} agent(s)',
            timestamp=datetime.now().isoformat(),
            details=details
        )
    
    def check_vllm(self) -> HealthStatus:
        """Check vLLM server connectivity"""
        details = {
            'host': self.vllm_host,
            'port': self.vllm_port
        }
        
        import requests
        
        # Try to connect to vLLM
        try:
            url = f"http://{self.vllm_host}:{self.vllm_port}/health"
            start_time = time.time()
            response = requests.get(url, timeout=5)
            response_time_ms = (time.time() - start_time) * 1000
            
            details['response_time_ms'] = round(response_time_ms, 2)
            details['status_code'] = response.status_code
            
            if response.status_code == 200:
                return HealthStatus(
                    component='vllm',
                    status='healthy',
                    message=f'vLLM responding in {response_time_ms:.2f}ms',
                    timestamp=datetime.now().isoformat(),
                    details=details
                )
            else:
                return HealthStatus(
                    component='vllm',
                    status='degraded',
                    message=f'vLLM returned HTTP {response.status_code}',
                    timestamp=datetime.now().isoformat(),
                    details=details
                )
                
        except requests.exceptions.ConnectionError:
            details['error'] = 'Connection refused'
            return HealthStatus(
                component='vllm',
                status='unhealthy',
                message=f'Cannot connect to vLLM at {self.vllm_host}:{self.vllm_port}',
                timestamp=datetime.now().isoformat(),
                details=details
            )
        except requests.exceptions.Timeout:
            details['error'] = 'Connection timeout'
            return HealthStatus(
                component='vllm',
                status='unhealthy',
                message=f'vLLM connection timeout',
                timestamp=datetime.now().isoformat(),
                details=details
            )
        except Exception as e:
            details['error'] = str(e)
            return HealthStatus(
                component='vllm',
                status='unhealthy',
                message=f'vLLM check failed: {e}',
                timestamp=datetime.now().isoformat(),
                details=details
            )
    
    def check_webui(self) -> HealthStatus:
        """Check Web UI availability"""
        details = {}
        
        # Check if port 8080 is listening
        import socket
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        
        try:
            result = sock.connect_ex(('localhost', 8080))
            if result == 0:
                details['port'] = 8080
                details['listening'] = True
                return HealthStatus(
                    component='webui',
                    status='healthy',
                    message='Web UI is running on port 8080',
                    timestamp=datetime.now().isoformat(),
                    details=details
                )
            else:
                details['port'] = 8080
                details['listening'] = False
                return HealthStatus(
                    component='webui',
                    status='unhealthy',
                    message='Web UI is not running on port 8080',
                    timestamp=datetime.now().isoformat(),
                    details=details
                )
        except Exception as e:
            details['error'] = str(e)
            return HealthStatus(
                component='webui',
                status='unhealthy',
                message=f'Web UI check failed: {e}',
                timestamp=datetime.now().isoformat(),
                details=details
            )
        finally:
            sock.close()
    
    def get_overall_status(self, components: List[HealthStatus]) -> str:
        """Determine overall health status from component statuses"""
        statuses = [c.status for c in components]
        
        if 'unhealthy' in statuses:
            return 'unhealthy'
        elif 'degraded' in statuses:
            return 'degraded'
        else:
            return 'healthy'
    
    def get_health(self, force_refresh: bool = False) -> SystemHealth:
        """
        Get overall system health.
        
        Args:
            force_refresh: Force fresh check (ignore cache)
        
        Returns:
            SystemHealth object
        """
        # Check cache
        now = time.time()
        if not force_refresh and self.health_cache and (now - self.last_check) < self.cache_ttl:
            return self.health_cache
        
        # Run all health checks
        components = {
            'system': self.check_system_resources(),
            'tmux': self.check_tmux(),
            'hcom': self.check_hcom(),
            'vllm': self.check_vllm(),
            'webui': self.check_webui()
        }
        
        # Determine overall status
        overall_status = self.get_overall_status(list(components.values()))
        
        # Calculate uptime
        uptime_seconds = time.time() - self.start_time
        
        # Create health object
        health = SystemHealth(
            status=overall_status,
            timestamp=datetime.now().isoformat(),
            components=components,
            uptime_seconds=round(uptime_seconds, 2),
            version=self.version
        )
        
        # Cache result
        self.health_cache = health
        self.last_check = now
        
        # Log if unhealthy
        if overall_status != 'healthy':
            logger.warning(f"System health: {overall_status}")
            for name, status in components.items():
                if status.status != 'healthy':
                    logger.warning(f"  {name}: {status.status} - {status.message}")
        
        return health
    
    def get_health_json(self, force_refresh: bool = False) -> str:
        """Get health as JSON string"""
        health = self.get_health(force_refresh)
        
        # Convert to dict for JSON serialization
        health_dict = {
            'status': health.status,
            'timestamp': health.timestamp,
            'uptime_seconds': health.uptime_seconds,
            'version': health.version,
            'components': {}
        }
        
        for name, status in health.components.items():
            health_dict['components'][name] = {
                'status': status.status,
                'message': status.message,
                'timestamp': status.timestamp,
                'details': status.details
            }
        
        return json.dumps(health_dict, indent=2)


# Singleton instance
_health_monitor = None


def get_health_monitor() -> HealthMonitor:
    """Get or create health monitor instance"""
    global _health_monitor
    if _health_monitor is None:
        _health_monitor = HealthMonitor()
    return _health_monitor


# CLI interface
if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='ai-colab Health Monitor')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--refresh', action='store_true', help='Force refresh')
    parser.add_argument('--component', type=str, help='Check specific component')
    
    args = parser.parse_args()
    
    monitor = get_health_monitor()
    
    if args.component:
        # Check specific component
        component_checks = {
            'system': monitor.check_system_resources,
            'tmux': monitor.check_tmux,
            'hcom': monitor.check_hcom,
            'vllm': monitor.check_vllm,
            'webui': monitor.check_webui
        }
        
        if args.component in component_checks:
            status = component_checks[args.component]()
            if args.json:
                print(json.dumps(asdict(status), indent=2))
            else:
                print(f"\n{args.component.upper()} Health")
                print("=" * 50)
                print(f"Status: {status.status}")
                print(f"Message: {status.message}")
                print(f"Timestamp: {status.timestamp}")
                print(f"Details: {json.dumps(status.details, indent=2)}")
        else:
            print(f"Unknown component: {args.component}")
            print(f"Available: {', '.join(component_checks.keys())}")
            sys.exit(1)
    else:
        # Check all components
        if args.json:
            print(monitor.get_health_json(args.refresh))
        else:
            health = monitor.get_health(args.refresh)
            
            print(f"\nai-colab Health Status")
            print("=" * 50)
            print(f"Overall: {health.status.upper()}")
            print(f"Timestamp: {health.timestamp}")
            print(f"Uptime: {health.uptime_seconds:.0f}s")
            print(f"Version: {health.version}")
            print()
            
            for name, status in health.components.items():
                status_icon = '✓' if status.status == 'healthy' else '⚠' if status.status == 'degraded' else '✗'
                print(f"{status_icon} {name.upper()}: {status.status}")
                print(f"  {status.message}")
