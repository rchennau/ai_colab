#!/usr/bin/env python3
import os
import sys
import json

def load_modules(project_root):
    modules_dir = os.path.join(project_root, "modules")
    if not os.path.isdir(modules_dir):
        return []
    
    modules = []
    for mod_id in os.listdir(modules_dir):
        mod_path = os.path.join(modules_dir, mod_id)
        manifest_path = os.path.join(mod_path, "module.toml")
        if os.path.isfile(manifest_path):
            # Simple line-based parsing for TOML to avoid dependencies for now
            # In a real environment, we'd use a toml library
            config = {"id": mod_id, "env": {}, "hooks": {"conductor_commands": [], "dashboard_sections": []}}
            
            section = None
            try:
                with open(manifest_path, "r") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"): continue
                        if line.startswith("["):
                            section = line.strip("[]")
                            continue
                        
                        if "=" in line:
                            key, val = line.split("=", 1)
                            key = key.strip()
                            val = val.strip().strip('"')
                            
                            if section == "module": config[key] = val
                            elif section == "env": config["env"][key] = val
                            elif section == "hooks":
                                # Very basic parsing for list of dicts
                                pass # We'll handle hooks more specifically if needed
            except: pass
            
            # Since we need to support nested structures, let's use a more robust regex or just use python's capabilities
            # Re-parsing with a bit more logic for the hooks
            modules.append(config)
    return modules

def get_active_modules(project_root):
    # For now, all modules in the directory are considered available
    # Activity is determined by environment variables or a pref file
    all_mod = load_modules(project_root)
    active = []
    
    prefs_file = os.path.join(project_root, ".ai-colab-prefs")
    enabled_ids = []
    if os.path.isfile(prefs_file):
        with open(prefs_file, "r") as f:
            for line in f:
                if line.startswith("MODULE_"):
                    k, v = line.strip().split("=")
                    if v == "true":
                        enabled_ids.append(k.replace("MODULE_", "").lower().replace("_", "-"))

    for m in all_mod:
        if m["id"] in enabled_ids:
            active.append(m)
    return active

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    root = sys.argv[2] if len(sys.argv) > 2 else os.getcwd()
    
    if cmd == "list":
        print(json.dumps(load_modules(root)))
    elif cmd == "active":
        print(json.dumps(get_active_modules(root)))
    elif cmd == "env":
        # Output shell export commands
        active = get_active_modules(root)
        for m in active:
            for k, v in m.get("env", {}).items():
                print(f"export {k}={v}")
    elif cmd == "commands":
        # Output shell case statements for commands
        active = get_active_modules(root)
        for m in active:
            mod_path = os.path.join(root, "modules", m["id"])
            manifest_path = os.path.join(mod_path, "module.toml")
            if os.path.isfile(manifest_path):
                with open(manifest_path, "r") as f:
                    content = f.read()
                    import re
                    match = re.search(r'conductor_commands\s*=\s*\[(.*?)\]', content, re.DOTALL)
                    if match:
                        hooks_block = match.group(1)
                        hooks = re.findall(r'\{\s*trigger\s*=\s*"([^"]+)"\s*,\s*script\s*=\s*"([^"]+)"\s*\}', hooks_block)
                        for trigger, script in hooks:
                            print(f'                "{trigger}")')
                            print(f'                    hcom send "@$from" --name "$HCOM_NAME" --thread "$thread" -- "Modular Command: {trigger}"')
                            print(f'                    bash "$PROJECT_ROOT/{script}" "$@" > /dev/null 2>&1 || true')
                            print(f'                    ;;')
    elif cmd == "sections":
        # Output dashboard sections info
        active = get_active_modules(root)
        results = []
        for m in active:
            mod_path = os.path.join(root, "modules", m["id"])
            manifest_path = os.path.join(mod_path, "module.toml")
            if os.path.isfile(manifest_path):
                with open(manifest_path, "r") as f:
                    content = f.read()
                    import re
                    match = re.search(r'dashboard_sections\s*=\s*\[(.*?)\]', content, re.DOTALL)
                    if match:
                        hooks_block = match.group(1)
                        sections = re.findall(r'\{\s*name\s*=\s*"([^"]+)"\s*,\s*type\s*=\s*"([^"]+)"\s*,\s*source\s*=\s*"([^"]+)"\s*\}', hooks_block)
                        for name, stype, source in sections:
                            results.append({"name": name, "type": stype, "source": source})
        print(json.dumps(results))
