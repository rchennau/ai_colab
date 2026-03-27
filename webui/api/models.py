"""
Model Registry API Blueprint
"""

from flask import Blueprint, request, jsonify

models_bp = Blueprint('models', __name__, url_prefix='/api/models')


@models_bp.route('', methods=['GET'])
def list_models():
    """List all registered models"""
    from webui.app import logger, PROJECT_ROOT
    
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from model_registry import get_registry
        
        registry = get_registry()
        models = registry.list_models()
        
        return jsonify({'models': models, 'count': len(models)})
        
    except Exception as e:
        logger.error(f"List models failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@models_bp.route('', methods=['POST'])
def register_model():
    """Register a new model"""
    from webui.app import logger, PROJECT_ROOT
    
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
            return jsonify({'status': 'error', 'error': 'Failed to register'}), 500
            
    except Exception as e:
        logger.error(f"Register model failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@models_bp.route('/<model_id>', methods=['GET'])
def get_model(model_id):
    """Get model information"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/<model_id>/versions', methods=['GET'])
def list_versions(model_id):
    """List all versions of a model"""
    from webui.app import logger, PROJECT_ROOT
    
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from model_registry import get_registry
        
        registry = get_registry()
        versions = registry.list_versions(model_id)
        
        return jsonify({
            'versions': [v.to_dict() for v in versions],
            'count': len(versions)
        })
        
    except Exception as e:
        logger.error(f"List versions failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@models_bp.route('/<model_id>/active', methods=['GET'])
def get_active_version(model_id):
    """Get currently active version"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/<model_id>/deploy', methods=['POST'])
def deploy_version(model_id):
    """Deploy a model version"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/<model_id>/rollback', methods=['POST'])
def rollback_version(model_id):
    """Rollback to previous version"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/ab-tests', methods=['GET'])
def list_ab_tests():
    """List A/B tests"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/ab-tests', methods=['POST'])
def create_ab_test():
    """Create a new A/B test"""
    from webui.app import logger, PROJECT_ROOT
    
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


@models_bp.route('/ab-tests/<test_id>/assign', methods=['GET'])
def get_ab_assignment(test_id):
    """Get model assignment for A/B test"""
    from webui.app import logger, PROJECT_ROOT
    import uuid
    
    try:
        sys.path.insert(0, str(PROJECT_ROOT / 'scripts'))
        from model_registry import get_registry
        
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
