"""
Inference Gateway API Blueprint
Handles all inference-related endpoints.
"""

from flask import Blueprint, request, jsonify, current_app
import asyncio
import sys
from pathlib import Path

inference_bp = Blueprint('inference', __name__, url_prefix='/api/inference')


@inference_bp.route('/v1/complete', methods=['POST'])
def complete():
    """Execute inference request"""
    project_root = current_app.config.get('PROJECT_ROOT')
    
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from inference import get_gateway
        
        gateway = get_gateway()
        data = request.json or {}
        
        if not data.get('prompt'):
            return jsonify({'status': 'error', 'error': 'Prompt required'}), 400
        
        response = asyncio.run(gateway.complete(**data))
        
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
        current_app.logger.error(f"Inference request failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@inference_bp.route('/v1/batch', methods=['POST'])
def batch():
    """Execute batch inference requests"""
    project_root = current_app.config.get('PROJECT_ROOT')
    
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from inference import get_gateway
        
        gateway = get_gateway()
        data = request.json
        
        if not data or not data.get('requests'):
            return jsonify({'status': 'error', 'error': 'Requests array required'}), 400
        
        tasks = [gateway.complete(**req) for req in data['requests']]
        responses = asyncio.run(asyncio.gather(*tasks, return_exceptions=True))
        
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
            'batch_id': f"batch_{int(asyncio.get_event_loop().time())}",
            'results': results,
            'total_requests': len(results),
            'successful': sum(1 for r in results if r['status'] == 'success')
        })
        
    except Exception as e:
        current_app.logger.error(f"Batch inference failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@inference_bp.route('/v1/metrics', methods=['GET'])
def metrics():
    """Get inference metrics"""
    project_root = current_app.config.get('PROJECT_ROOT')
    
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from inference import get_gateway
        
        gateway = get_gateway()
        metrics = gateway.get_metrics()
        
        return jsonify(metrics)
        
    except Exception as e:
        current_app.logger.error(f"Metrics request failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@inference_bp.route('/v1/models', methods=['GET'])
def models():
    """Get available models and their status"""
    project_root = current_app.config.get('PROJECT_ROOT')
    
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
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
        current_app.logger.error(f"Models request failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500
