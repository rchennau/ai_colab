"""
Config API Blueprint (configuration management)
"""

import json
import logging
from datetime import datetime
from flask import Blueprint, request, jsonify, current_app
import toml
import jsonschema

config_bp = Blueprint('config', __name__, url_prefix='/api/config')


@config_bp.route('', methods=['GET'])
def get_config():
    """Get current configuration"""
    project_root = current_app.config.get('PROJECT_ROOT')
    config_file = project_root / "config" / "config.toml"
    
    try:
        if not config_file.exists():
            return jsonify({"error": "Configuration not found"}), 404
        
        with open(config_file, 'r') as f:
            config = toml.load(f)
        
        return jsonify(config)
    except Exception as e:
        current_app.logger.error(f"Error reading config: {e}")
        return jsonify({"error": str(e)}), 500


@config_bp.route('', methods=['PUT'])
def update_config():
    """Update configuration"""
    project_root = current_app.config.get('PROJECT_ROOT')
    config_dir = project_root / "config"
    config_file = config_dir / "config.toml"
    schema_file = config_dir / "config.schema.json"
    
    try:
        new_config = request.json
        
        # Validate against schema if available
        if schema_file.exists():
            with open(schema_file, 'r') as f:
                schema = json.load(f)
            jsonschema.validate(instance=new_config, schema=schema)
        
        # Convert to TOML and write
        config_content = toml.dumps(new_config)
        
        # Backup existing config
        if config_file.exists():
            backup_dir = config_dir / "backups"
            backup_dir.mkdir(exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup_file = backup_dir / f"config.{timestamp}.toml"
            import shutil
            shutil.copy(config_file, backup_file)
            current_app.logger.info(f"Backup created: {backup_file}")
        
        # Write new config
        with open(config_file, 'w') as f:
            f.write(config_content)
        
        current_app.logger.info("Configuration updated successfully")
        return jsonify({"status": "success", "message": "Configuration updated"})
        
    except jsonschema.ValidationError as e:
        current_app.logger.error(f"Validation error: {e}")
        return jsonify({"error": "Validation failed", "details": str(e)}), 400
    except Exception as e:
        current_app.logger.error(f"Error updating config: {e}")
        return jsonify({"error": str(e)}), 500


@config_bp.route('/validate', methods=['POST'])
def validate_config():
    """Validate configuration against schema"""
    project_root = current_app.config.get('PROJECT_ROOT')
    schema_file = project_root / "config" / "config.schema.json"
    
    try:
        config = request.json
        
        if schema_file.exists():
            with open(schema_file, 'r') as f:
                schema = json.load(f)
            jsonschema.validate(instance=config, schema=schema)
            return jsonify({"valid": True})
        else:
            return jsonify({"valid": True, "warning": "Schema not found"})
            
    except jsonschema.ValidationError as e:
        return jsonify({"valid": False, "error": str(e)})
