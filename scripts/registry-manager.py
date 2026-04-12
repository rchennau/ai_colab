#!/usr/bin/env python3
"""
ai-colab Registry Manager
Helper for maintainers to manage the module index.json.
"""

import json
import argparse
import os
from datetime import datetime
from pathlib import Path

REGISTRY_PATH = Path("registry/index.json")

def load_registry():
    if not REGISTRY_PATH.exists():
        return {"version": "1.0.0", "last_updated": "", "modules": []}
    with open(REGISTRY_PATH, 'r') as f:
        return json.load(f)

def save_registry(data):
    data["last_updated"] = datetime.utcnow().isoformat() + "Z"
    with open(REGISTRY_PATH, 'w') as f:
        json.dump(data, f, indent=2)

def add_module(args):
    registry = load_registry()
    
    # Check if exists
    for m in registry["modules"]:
        if m["id"] == args.id:
            print(f"Updating existing module: {args.id}")
            m.update({
                "name": args.name or m["name"],
                "description": args.desc or m["description"],
                "url": args.url or m["url"],
                "author": args.author or m["author"],
                "version": args.version or m["version"]
            })
            save_registry(registry)
            return

    # Add new
    new_mod = {
        "id": args.id,
        "name": args.name,
        "description": args.desc,
        "url": args.url,
        "author": args.author,
        "version": args.version
    }
    registry["modules"].append(new_mod)
    save_registry(registry)
    print(f"Added new module: {args.id}")

def remove_module(args):
    registry = load_registry()
    original_count = len(registry["modules"])
    registry["modules"] = [m for m in registry["modules"] if m["id"] != args.id]
    
    if len(registry["modules"]) < original_count:
        save_registry(registry)
        print(f"Removed module: {args.id}")
    else:
        print(f"Module not found: {args.id}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Manage ai-colab Registry")
    subparsers = parser.add_subparsers(dest="command")

    add_p = subparsers.add_parser("add")
    add_p.add_argument("--id", required=True)
    add_p.add_argument("--name", required=True)
    add_p.add_argument("--desc", required=True)
    add_p.add_argument("--url", required=True)
    add_p.add_argument("--author", required=True)
    add_p.add_argument("--version", default="1.0.0")

    rem_p = subparsers.add_parser("remove")
    rem_p.add_argument("--id", required=True)

    args = parser.parse_args()

    if args.command == "add":
        add_module(args)
    elif args.command == "remove":
        remove_module(args)
    else:
        parser.print_help()
