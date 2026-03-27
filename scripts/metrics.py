"""
ai-colab Metrics Collection and Export
Prometheus-compatible metrics for observability stack.
"""

import time
import threading
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field
from collections import defaultdict


@dataclass
class MetricSample:
    """Single metric sample"""
    name: str
    value: float
    timestamp: float
    labels: Dict[str, str] = field(default_factory=dict)


class MetricsRegistry:
    """
    Prometheus-compatible metrics registry.
    
    Supports:
    - Counter: Monotonically increasing values
    - Gauge: Values that can go up or down
    - Histogram: Distribution of values
    - Summary: Statistical summaries
    """
    
    def __init__(self):
        self._metrics: Dict[str, List[MetricSample]] = defaultdict(list)
        self._counters: Dict[str, float] = {}
        self._gauges: Dict[str, float] = {}
        self._histograms: Dict[str, List[float]] = defaultdict(list)
        self._lock = threading.Lock()
        
        # Default labels
        self._default_labels = {
            'service': 'ai-colab',
            'version': '2.2.0'
        }
    
    def counter(self, name: str, value: float = 1.0, labels: Dict[str, str] = None):
        """
        Increment a counter metric.
        
        Args:
            name: Metric name
            value: Value to increment by (default: 1)
            labels: Additional labels
        """
        with self._lock:
            key = self._make_key(name, labels)
            self._counters[key] = self._counters.get(key, 0) + value
            
            self._metrics[name].append(MetricSample(
                name=name,
                value=self._counters[key],
                timestamp=time.time(),
                labels={**self._default_labels, **(labels or {})}
            ))
    
    def gauge(self, name: str, value: float, labels: Dict[str, str] = None):
        """
        Set a gauge metric.
        
        Args:
            name: Metric name
            value: Gauge value
            labels: Additional labels
        """
        with self._lock:
            key = self._make_key(name, labels)
            self._gauges[key] = value
            
            self._metrics[name].append(MetricSample(
                name=name,
                value=value,
                timestamp=time.time(),
                labels={**self._default_labels, **(labels or {})}
            ))
    
    def histogram(self, name: str, value: float, labels: Dict[str, str] = None):
        """
        Record a histogram value.
        
        Args:
            name: Metric name
            value: Value to record
            labels: Additional labels
        """
        with self._lock:
            key = self._make_key(name, labels)
            self._histograms[key].append(value)
            
            # Keep only last 1000 values per histogram
            if len(self._histograms[key]) > 1000:
                self._histograms[key] = self._histograms[key][-1000:]
    
    def _make_key(self, name: str, labels: Dict[str, str] = None) -> str:
        """Create unique key for metric"""
        label_str = ','.join(f'{k}={v}' for k, v in sorted((labels or {}).items()))
        return f"{name}:{label_str}" if label_str else name
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get all metrics as dictionary"""
        with self._lock:
            return {
                'counters': dict(self._counters),
                'gauges': dict(self._gauges),
                'histograms': {
                    k: {
                        'count': len(v),
                        'sum': sum(v),
                        'avg': sum(v) / len(v) if v else 0,
                        'min': min(v) if v else 0,
                        'max': max(v) if v else 0,
                        'p50': self._percentile(v, 50),
                        'p95': self._percentile(v, 95),
                        'p99': self._percentile(v, 99)
                    }
                    for k, v in self._histograms.items()
                }
            }
    
    def _percentile(self, data: List[float], percentile: int) -> float:
        """Calculate percentile"""
        if not data:
            return 0
        sorted_data = sorted(data)
        index = int(len(sorted_data) * percentile / 100)
        return sorted_data[min(index, len(sorted_data) - 1)]
    
    def to_prometheus(self) -> str:
        """Export metrics in Prometheus text format"""
        lines = []
        
        with self._lock:
            # Counters
            for key, value in self._counters.items():
                name = key.split(':')[0]
                labels = key.split(':')[1] if ':' in key else ''
                label_str = '{' + labels + '}' if labels else ''
                lines.append(f"{name}{label_str} {value}")
            
            # Gauges
            for key, value in self._gauges.items():
                name = key.split(':')[0]
                labels = key.split(':')[1] if ':' in key else ''
                label_str = '{' + labels + '}' if labels else ''
                lines.append(f"{name}{label_str} {value}")
            
            # Histograms
            for key, values in self._histograms.items():
                if not values:
                    continue
                name = key.split(':')[0]
                labels = key.split(':')[1] if ':' in key else ''
                label_str = '{' + labels + '}' if labels else ''
                
                lines.append(f"{name}_count{label_str} {len(values)}")
                lines.append(f"{name}_sum{label_str} {sum(values)}")
                lines.append(f"{name}_avg{label_str} {sum(values) / len(values)}")
        
        return '\n'.join(lines)


# Global metrics registry
_metrics_registry = None


def get_metrics_registry() -> MetricsRegistry:
    """Get or create metrics registry"""
    global _metrics_registry
    if _metrics_registry is None:
        _metrics_registry = MetricsRegistry()
    return _metrics_registry


# Convenience functions for common metrics
def record_api_request(method: str, endpoint: str, status: int, duration_ms: float):
    """Record API request metrics"""
    registry = get_metrics_registry()
    
    registry.counter('ai_colab_api_requests_total', labels={
        'method': method,
        'endpoint': endpoint,
        'status': str(status)
    })
    
    registry.histogram('ai_colab_api_request_duration_ms', duration_ms, labels={
        'method': method,
        'endpoint': endpoint
    })


def record_error(component: str, error_type: str):
    """Record error metric"""
    registry = get_metrics_registry()
    
    registry.counter('ai_colab_errors_total', labels={
        'component': component,
        'error_type': error_type
    })


def record_health_check(component: str, status: str):
    """Record health check result"""
    registry = get_metrics_registry()
    
    registry.gauge('ai_colab_health_status', 1 if status == 'healthy' else 0, labels={
        'component': component,
        'status': status
    })


def record_agent_status(agent_name: str, status: str):
    """Record agent status"""
    registry = get_metrics_registry()
    
    status_value = {'ready': 1, 'busy': 0.5, 'error': 0}.get(status, 0)
    registry.gauge('ai_colab_agent_status', status_value, labels={
        'agent': agent_name,
        'status': status
    })


def record_system_metric(name: str, value: float, labels: Dict[str, str] = None):
    """Record custom system metric"""
    registry = get_metrics_registry()
    registry.gauge(f'ai_colab_{name}', value, labels=labels)
