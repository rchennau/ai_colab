"""
Vision/Screenshot API Blueprint
"""

from flask import Blueprint, request, jsonify, current_app
import sys

vision_bp = Blueprint('vision', __name__, url_prefix='/api/vision')


@vision_bp.route('/screenshot', methods=['POST'])
def capture_screenshot():
    """Capture and analyze screenshot"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        import asyncio
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from vision import get_vision_client
        
        data = request.json or {}
        prompt = data.get('prompt', "What's in this screenshot?")
        model = data.get('model', 'gemini')
        
        client = get_vision_client(model)
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(client.analyze_screenshot(prompt))
        finally:
            loop.close()
        
        return jsonify(result) if result.get('success') else \
               jsonify({'status': 'error', 'error': result.get('error')}), 500
    except Exception as e:
        current_app.logger.error(f"Screenshot analysis failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@vision_bp.route('/analyze', methods=['POST'])
def analyze_image():
    """Analyze uploaded image"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        import asyncio, base64, tempfile, os
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from vision import get_vision_client
        
        if 'image' not in request.files:
            data = request.json
            if not data or 'image_base64' not in data:
                return jsonify({'status': 'error', 'error': 'No image provided'}), 400
            image_data = base64.b64decode(data['image_base64'])
            with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as f:
                f.write(image_data)
                image_path = f.name
        else:
            file = request.files['image']
            with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as f:
                file.save(f.name)
                image_path = f.name
        
        try:
            prompt = request.form.get('prompt', "What's in this image?")
            model = request.form.get('model', 'gemini')
            
            client = get_vision_client(model)
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                analysis = loop.run_until_complete(client.analyze_image(image_path, prompt))
            finally:
                loop.close()
            
            return jsonify({'status': 'success', 'analysis': analysis, 'model': model})
        finally:
            os.unlink(image_path)
    except Exception as e:
        current_app.logger.error(f"Image analysis failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@vision_bp.route('/images', methods=['GET'])
def list_images():
    """List stored images"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from vision import VisionManager
        vision = VisionManager()
        image_type = request.args.get('type')
        limit = request.args.get('limit', 50, type=int)
        images = vision.list_images(image_type, limit)
        return jsonify({'images': images, 'count': len(images)})
    except Exception as e:
        current_app.logger.error(f"List images failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@vision_bp.route('/images/<image_id>', methods=['GET'])
def get_image(image_id):
    """Get image info or download"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from vision import VisionManager
        vision = VisionManager()
        image_info = vision.get_image(image_id)
        if not image_info:
            return jsonify({'status': 'error', 'error': 'Image not found'}), 404
        if request.args.get('download'):
            from flask import send_file
            return send_file(image_info['path'], as_attachment=True)
        return jsonify({'status': 'success', 'image': image_info})
    except Exception as e:
        current_app.logger.error(f"Get image failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500


@vision_bp.route('/images/<image_id>', methods=['DELETE'])
def delete_image(image_id):
    """Delete image"""
    project_root = current_app.config.get('PROJECT_ROOT')
    try:
        if str(project_root / 'scripts') not in sys.path:
            sys.path.insert(0, str(project_root / 'scripts'))
        from vision import VisionManager
        vision = VisionManager()
        success = vision.delete_image(image_id)
        return jsonify({'status': 'success', 'message': 'Image deleted'}) if success else \
               jsonify({'status': 'error', 'error': 'Image not found'}), 404
    except Exception as e:
        current_app.logger.error(f"Delete image failed: {e}")
        return jsonify({'status': 'error', 'error': str(e)}), 500
