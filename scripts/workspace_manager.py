#!/usr/bin/env python3
import os
import json
import argparse
from pathlib import Path

def find_git_repos(start_dir, max_depth=2):
    """Scan directory for .git subdirectories up to max_depth."""
    repos = []
    start_path = Path(start_dir).resolve()
    
    # Check if start_dir itself is a git repo
    if (start_path / ".git").is_dir():
        repos.append({
            "name": start_path.name,
            "path": str(start_path),
            "id": start_path.name.lower().replace(" ", "_")
        })

    # Walk with depth limit
    for root, dirs, files in os.walk(start_path):
        depth = Path(root).relative_to(start_path).parts
        if len(depth) >= max_depth:
            dirs[:] = [] # Stop recursion
            continue
            
        for d in dirs:
            dir_path = Path(root) / d
            if (dir_path / ".git").is_dir():
                repos.append({
                    "name": dir_path.name,
                    "path": str(dir_path),
                    "id": dir_path.name.lower().replace(" ", "_")
                })
    return repos

def load_workspace(config_path):
    if not config_path.exists():
        return {"projects": []}
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except:
        return {"projects": []}

def save_workspace(config_path, data):
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)

def register_project(config_path, project_path):
    workspace = load_workspace(config_path)
    p_path = Path(project_path).resolve()
    
    # Check if already registered
    for p in workspace["projects"]:
        if p["path"] == str(p_path):
            return p
            
    project = {
        "id": p_path.name.lower().replace(" ", "_"),
        "name": p_path.name,
        "path": str(p_path),
        "active": False
    }
    workspace["projects"].append(project)
    save_workspace(config_path, workspace)
    return project

def list_projects(config_path):
    workspace = load_workspace(config_path)
    return workspace["projects"]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ai-colab Workspace Manager")
    parser.add_argument("command", choices=["scan", "register", "list"])
    parser.add_argument("--path", help="Path to scan or register")
    parser.add_argument("--config", help="Path to workspace config file")
    
    args = parser.parse_args()
    
    config_path = Path(args.config or Path.home() / ".ai-colab" / "config" / "workspace.json")
    
    if args.command == "scan":
        path = args.path or os.getcwd()
        repos = find_git_repos(path)
        print(json.dumps(repos))
    elif args.command == "register":
        if not args.path:
            print("Error: --path required for register")
            exit(1)
        project = register_project(config_path, args.path)
        print(json.dumps(project))
    elif args.command == "list":
        projects = list_projects(config_path)
        print(json.dumps(projects))
