#!/usr/bin/env python3
import os
import sys
import json
import re
from pathlib import Path

# Try to import jsonschema for validation
try:
    from jsonschema import validate
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

def parse_toml_basic(content):
    """Very basic TOML parser for simple flat structures and hooks lists."""
    data = {}
    current_section = None
    
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith('#'): continue
        if line.startswith('['):
            current_section = line.strip('[]')
            if current_section not in data:
                data[current_section] = {}
            continue
            
        if '=' in line:
            key, val = line.split('=', 1)
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            
            # Basic support for boolean
            if val.lower() == 'true': val = True
            elif val.lower() == 'false': val = False
            
            if current_section:
                data[current_section][key] = val
            else:
                data[key] = val
    return data

def load_module_manifest(manifest_path):
    """Load and parse module.toml using regex for structured lists."""
    if not os.path.isfile(manifest_path):
        return None
        
    with open(manifest_path, 'r') as f:
        content = f.read()
        
    # Start with basic sections
    data = parse_toml_basic(content)
    
    # Handle complex lists using regex (more reliable than the basic parser)
    # 1. conductor_commands
    commands = re.findall(r'\{\s*trigger\s*=\s*"([^"]+)"\s*,\s*script\s*=\s*"([^"]+)"\s*\}', content)
    if commands:
        if 'hooks' not in data: data['hooks'] = {}
        data['hooks']['conductor_commands'] = [{"trigger": t, "script": s} for t, s in commands]
        
    # 2. periodic_hooks
    periodic = re.findall(r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*script\s*=\s*"([^"]+)"\s*,\s*interval\s*=\s*([0-9]+)\s*\}', content)
    if periodic:
        if 'hooks' not in data: data['hooks'] = {}
        data['hooks']['periodic_hooks'] = [{"name": n, "script": s, "interval": int(i)} for n, s, i in periodic]
        
    # 3. dashboard_sections
    sections = re.findall(r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*type\s*=\s*"([^"]+)"\s*,\s*source\s*=\s*"([^"]+)"\s*\}', content)
    if sections:
        if 'hooks' not in data: data['hooks'] = {}
        data['hooks']['dashboard_sections'] = [{"name": n, "type": t, "source": s} for n, t, s in sections]

    # 4. dependencies (python and system arrays)
    for dep_type in ['python', 'system']:
        dep_match = re.search(fr'{dep_type}\s*=\s*\[(.*?)\]', content)
        if dep_match:
            if 'dependencies' not in data: data['dependencies'] = {}
            deps = [d.strip().strip('"').strip("'") for d in dep_match.group(1).split(',') if d.strip()]
            data['dependencies'][dep_type] = deps

    # 5. MCP args array
    mcp_args = re.search(r'args\s*=\s*\[(.*?)\]', content)
    if mcp_args:
        if 'mcp' not in data: data['mcp'] = {}
        args = [a.strip().strip('"').strip("'") for a in mcp_args.group(1).split(',') if a.strip()]
        data['mcp']['args'] = args

    # 6. Ensure all env values are strings (schema requirement)
    if 'env' in data:
        for k, v in data['env'].items():
            if not isinstance(v, str):
                data['env'][k] = str(v).lower()

    return data

def validate_module(project_root, module_id, schema_path=None):
    """Validate a module manifest against the schema."""
    manifest_path = os.path.join(project_root, "modules", module_id, "module.toml")
    if not os.path.isfile(manifest_path):
        return False, "Manifest not found"
        
    if not schema_path:
        schema_path = os.path.join(project_root, "config", "module.schema.json")
        
    if not os.path.isfile(schema_path):
        return True, "Schema not found, skipping validation"
        
    try:
        manifest_data = load_module_manifest(manifest_path)
        if not HAS_JSONSCHEMA:
            return True, "jsonschema not installed, skipping deep validation"
            
        with open(schema_path, 'r') as f:
            schema = json.load(f)
            
        validate(instance=manifest_data, schema=schema)
        return True, "Valid"
    except Exception as e:
        return False, str(e)

def load_modules(project_root):
    modules_dir = os.path.join(project_root, "modules")
    if not os.path.isdir(modules_dir):
        return []

    modules = []
    for mod_id in os.listdir(modules_dir):
        mod_path = os.path.join(modules_dir, mod_id)
        if not os.path.isdir(mod_path): continue
        
        manifest_path = os.path.join(mod_path, "module.toml")
        manifest = load_module_manifest(manifest_path)
        if manifest:
            # Flatten for easier usage in UI
            info = {
                "id": mod_id,
                "name": manifest.get("module", {}).get("name", mod_id),
                "description": manifest.get("module", {}).get("description", ""),
                "version": manifest.get("module", {}).get("version", "0.0.0"),
                "env": manifest.get("env", {}),
                "hooks": manifest.get("hooks", {})
            }
            modules.append(info)
    return modules

def get_prefs_file(project_root):
    return os.path.join(project_root, ".ai-colab-prefs")

def get_enabled_module_ids(project_root):
    """Get list of enabled module IDs from prefs file"""
    prefs_file = get_prefs_file(project_root)
    enabled_ids = []
    if os.path.isfile(prefs_file):
        with open(prefs_file, "r") as f:
            for line in f:
                if line.startswith("MODULE_"):
                    try:
                        k, v = line.strip().split("=", 1)
                        if v == "true":
                            enabled_ids.append(k.replace("MODULE_", "").lower().replace("_", "-"))
                    except: pass
    return enabled_ids

def get_active_modules(project_root):
    all_mod = load_modules(project_root)
    enabled_ids = get_enabled_module_ids(project_root)
    return [m for m in all_mod if m["id"] in enabled_ids]

def enable_module(project_root, module_id):
    prefs_file = get_prefs_file(project_root)
    pref_key = "MODULE_" + module_id.upper().replace("-", "_")
    
    prefs = {}
    if os.path.isfile(prefs_file):
        with open(prefs_file, "r") as f:
            for line in f:
                if "=" in line:
                    try:
                        k, v = line.strip().split("=", 1)
                        prefs[k] = v
                    except: pass
    
    prefs[pref_key] = "true"
    with open(prefs_file, "w") as f:
        for k, v in prefs.items():
            f.write(f"{k}={v}\n")
    return True

def disable_module(project_root, module_id):
    prefs_file = get_prefs_file(project_root)
    pref_key = "MODULE_" + module_id.upper().replace("-", "_")
    
    prefs = {}
    if os.path.isfile(prefs_file):
        with open(prefs_file, "r") as f:
            for line in f:
                if "=" in line:
                    try:
                        k, v = line.strip().split("=", 1)
                        prefs[k] = v
                    except: pass
    
    prefs[pref_key] = "false"
    with open(prefs_file, "w") as f:
        for k, v in prefs.items():
            f.write(f"{k}={v}\n")
    return True

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    root = sys.argv[2] if len(sys.argv) > 2 else os.getcwd()

    if cmd == "list":
        print(json.dumps(load_modules(root)))
    elif cmd == "active":
        print(json.dumps(get_active_modules(root)))
    elif cmd == "validate-all":
        results = {}
        modules_dir = os.path.join(root, "modules")
        if os.path.isdir(modules_dir):
            for mod_id in os.listdir(modules_dir):
                if os.path.isdir(os.path.join(modules_dir, mod_id)):
                    valid, msg = validate_module(root, mod_id)
                    results[mod_id] = {"valid": valid, "message": msg}
        print(json.dumps(results))
    elif cmd == "info":
        module_id = sys.argv[3] if len(sys.argv) > 3 else None
        if not module_id:
            print(json.dumps({"status": "error", "message": "Module ID required"}))
            sys.exit(1)
        manifest_path = os.path.join(root, "modules", module_id, "module.toml")
        manifest = load_module_manifest(manifest_path)
        if manifest:
            print(json.dumps(manifest))
        else:
            print(json.dumps({"status": "error", "message": "Module not found"}))
            sys.exit(1)
    elif cmd == "status":
        all_modules = load_modules(root)
        enabled_ids = get_enabled_module_ids(root)
        result = []
        for mod in all_modules:
            result.append({
                "id": mod["id"],
                "name": mod["name"],
                "enabled": mod["id"] in enabled_ids
            })
        print(json.dumps(result))
    elif cmd == "enable":
        module_id = sys.argv[3] if len(sys.argv) > 3 else None
        if module_id:
            enable_module(root, module_id)
            print(json.dumps({"status": "success", "module": module_id}))
    elif cmd == "disable":
        module_id = sys.argv[3] if len(sys.argv) > 3 else None
        if module_id:
            disable_module(root, module_id)
            print(json.dumps({"status": "success", "module": module_id}))
    elif cmd == "env":
        active = get_active_modules(root)
        for m in active:
            for k, v in m.get("env", {}).items():
                print(f"export {k}={v}")
    elif cmd == "sections":
        active = get_active_modules(root)
        results = []
        for m in active:
            for section in m.get("hooks", {}).get("dashboard_sections", []):
                results.append(section)
        print(json.dumps(results))
    elif cmd == "commands":
        active = get_active_modules(root)
        for m in active:
            for hook in m.get("hooks", {}).get("conductor_commands", []):
                trigger = hook["trigger"]
                script = hook["script"]
                print(f'                "{trigger}")')
                print(f'                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Modular Command: {trigger}"')
                print(f'                    bash "$PROJECT_ROOT/{script}" "$@" > /dev/null 2>&1 || true')
                print(f'                    ;;')

