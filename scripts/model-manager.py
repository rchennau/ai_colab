#!/usr/bin/env python3
"""
ai-colab Local Model Manager (P5.1)
Manages local LLM models with Ollama, llama.cpp, and local vLLM support.

Features:
- Model registry with download URLs, sizes, and quantization info
- Download/install models with progress tracking
- Health checks for local model runtimes
- Model listing and status
- Zero-cloud bootstrap support

Usage:
    python3 model-manager.py list
    python3 model-manager.py download qwen2.5-coder-7b
    python3 model-manager.py status
    python3 model-manager.py health
    python3 model-manager.py recommend --task coding
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
LOCAL_MODELS_FILE = PROJECT_ROOT / "config" / "local-models.json"

# Default configuration
DEFAULT_CONFIG = {
    "download_timeout": 3600,
    "max_concurrent_downloads": 2,
    "health_check_interval": 60,
}


class LocalModelManager:
    """Manages local LLM models."""

    def __init__(self, config_file: Path = LOCAL_MODELS_FILE):
        self.config = self._load_config(config_file)
        self.runtimes = self.config.get("runtimes", {})
        self.models = self.config.get("models", {})
        self.defaults = self.config.get("defaults", {})

    def _load_config(self, config_file: Path) -> Dict[str, Any]:
        """Load local models configuration."""
        if config_file.exists():
            with open(config_file) as f:
                return json.load(f)
        return {}

    def list_models(self, runtime: Optional[str] = None) -> List[Dict[str, Any]]:
        """List available models, optionally filtered by runtime."""
        models = []
        for model_id, model_info in self.models.items():
            if runtime and model_info.get("runtime") != runtime:
                continue
            models.append({
                "id": model_id,
                "display_name": model_info.get("display_name", model_id),
                "runtime": model_info.get("runtime", "unknown"),
                "size_gb": model_info.get("size_gb", 0),
                "capabilities": model_info.get("capabilities", []),
                "min_ram_gb": model_info.get("min_ram_gb", 0),
            })
        return models

    def get_model_info(self, model_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a specific model."""
        return self.models.get(model_id)

    def download_model(self, model_id: str) -> bool:
        """Download/install a model."""
        model_info = self.get_model_info(model_id)
        if not model_info:
            print(f"Error: Model '{model_id}' not found in registry")
            return False

        runtime = model_info.get("runtime", "ollama")
        runtime_config = self.runtimes.get(runtime, {})

        if runtime == "ollama":
            return self._download_ollama_model(model_id, model_info)
        elif runtime == "llamacpp":
            return self._download_llamacpp_model(model_id, model_info)
        elif runtime == "vllm_local":
            return self._download_vllm_model(model_id, model_info)
        else:
            print(f"Error: Unsupported runtime '{runtime}'")
            return False

    def _download_ollama_model(self, model_id: str, model_info: Dict[str, Any]) -> bool:
        """Download model via Ollama."""
        download_cmd = model_info.get("download_url", f"ollama pull {model_id}")

        print(f"Downloading {model_info.get('display_name', model_id)} via Ollama...")
        print(f"Command: {download_cmd}")
        print(f"Size: {model_info.get('size_gb', 'unknown')} GB")
        print(f"Minimum RAM: {model_info.get('min_ram_gb', 'unknown')} GB")
        print()

        try:
            # Check if Ollama is installed
            result = subprocess.run(
                ["which", "ollama"],
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print("Error: Ollama is not installed.")
                print("Install with: curl -fsSL https://ollama.com/install.sh | sh")
                return False

            # Pull the model
            process = subprocess.run(
                download_cmd.split(),
                capture_output=True,
                text=True,
                timeout=self.defaults.get("download_timeout", 3600),
            )

            if process.returncode == 0:
                print(f"✓ Successfully downloaded {model_info.get('display_name', model_id)}")
                return True
            else:
                print(f"Error: Download failed: {process.stderr}")
                return False

        except subprocess.TimeoutExpired:
            print(f"Error: Download timed out after {self.defaults.get('download_timeout', 3600)}s")
            return False
        except Exception as e:
            print(f"Error: {e}")
            return False

    def _download_llamacpp_model(self, model_id: str, model_info: Dict[str, Any]) -> bool:
        """Download model for llama.cpp."""
        print(f"llama.cpp model download not yet implemented for {model_id}")
        return False

    def _download_vllm_model(self, model_id: str, model_info: Dict[str, Any]) -> bool:
        """Download model for local vLLM."""
        print(f"Local vLLM model download not yet implemented for {model_id}")
        return False

    def check_health(self) -> Dict[str, Any]:
        """Check health of all local model runtimes."""
        health = {}

        # Check Ollama
        health["ollama"] = self._check_ollama_health()

        # Check llama.cpp
        health["llamacpp"] = self._check_llamacpp_health()

        # Check local vLLM
        health["vllm_local"] = self._check_vllm_health()

        return health

    def _check_ollama_health(self) -> Dict[str, Any]:
        """Check Ollama runtime health."""
        try:
            result = subprocess.run(
                ["curl", "-f", "-s", "http://localhost:11434/api/tags"],
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode == 0:
                # Parse response to get downloaded models
                try:
                    response = json.loads(result.stdout)
                    downloaded_models = [m.get("name", "") for m in response.get("models", [])]
                except (json.JSONDecodeError, KeyError):
                    downloaded_models = []

                return {
                    "status": "healthy",
                    "downloaded_models": downloaded_models,
                    "model_count": len(downloaded_models),
                }
            else:
                return {
                    "status": "unhealthy",
                    "error": "Ollama server not responding",
                }

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {
                "status": "not_installed",
                "error": "Ollama not found",
            }

    def _check_llamacpp_health(self) -> Dict[str, Any]:
        """Check llama.cpp runtime health."""
        # Check if llama.cpp binary exists
        llama_cpp_paths = [
            PROJECT_ROOT / "llama.cpp" / "main",
            Path.home() / "llama.cpp" / "main",
        ]

        for path in llama_cpp_paths:
            if path.exists() and path.is_file():
                return {
                    "status": "healthy",
                    "binary": str(path),
                }

        return {
            "status": "not_installed",
            "error": "llama.cpp binary not found",
        }

    def _check_vllm_health(self) -> Dict[str, Any]:
        """Check local vLLM runtime health."""
        try:
            result = subprocess.run(
                ["curl", "-f", "-s", "http://localhost:8000/v1/models"],
                capture_output=True,
                text=True,
                timeout=5,
            )

            if result.returncode == 0:
                return {
                    "status": "healthy",
                    "endpoint": "http://localhost:8000",
                }
            else:
                return {
                    "status": "unhealthy",
                    "error": "vLLM server not responding",
                }

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {
                "status": "not_running",
                "error": "vLLM not found",
            }

    def recommend_model(self, task: str) -> Optional[str]:
        """Recommend a model for a given task type."""
        task_lower = task.lower()

        for model_id, model_info in self.models.items():
            capabilities = model_info.get("capabilities", [])
            recommended_for = model_info.get("recommended_for", [])

            # Check if model is recommended for this task
            if any(task_lower in rec for rec in recommended_for):
                return model_id

            # Check capabilities match
            if task_lower in ["coding", "code", "debug"] and "coding" in capabilities:
                return model_id
            elif task_lower in ["reasoning", "logic", "math"] and "reasoning" in capabilities:
                return model_id
            elif task_lower in ["architecture", "design"] and "architecture" in capabilities:
                return model_id
            elif task_lower in ["documentation", "writing", "summary"] and "documentation" in capabilities:
                return model_id

        # Return default if no match
        return self.defaults.get("recommended_model")

    def get_status(self) -> Dict[str, Any]:
        """Get overall local model status."""
        health = self.check_health()
        available_models = self.list_models()

        return {
            "health": health,
            "available_models": len(available_models),
            "downloaded_models": sum(
                1 for m in available_models
                if m["runtime"] == "ollama" and m["id"] in health.get("ollama", {}).get("downloaded_models", [])
            ),
            "runtimes": {
                runtime: info["status"]
                for runtime, info in health.items()
            },
        }


def main():
    parser = argparse.ArgumentParser(description="ai-colab Local Model Manager")
    parser.add_argument(
        "command",
        choices=["list", "download", "status", "health", "recommend", "help"],
        help="Command to execute",
    )
    parser.add_argument("--model", help="Model ID for download/recommend")
    parser.add_argument("--task", help="Task type for recommendation")
    parser.add_argument("--runtime", help="Filter by runtime (ollama/llamacpp/vllm_local)")

    args = parser.parse_args()

    if args.command == "help":
        parser.print_help()
        return

    manager = LocalModelManager()

    if args.command == "list":
        models = manager.list_models(runtime=args.runtime)
        if models:
            print(f"\nAvailable Models ({len(models)}):")
            print(f"{'ID':<30} {'Name':<25} {'Runtime':<12} {'Size':<8} {'Capabilities'}")
            print("-" * 100)
            for m in models:
                caps = ", ".join(m["capabilities"])
                print(f"{m['id']:<30} {m['display_name']:<25} {m['runtime']:<12} {m['size_gb']}GB     {caps}")
        else:
            print("No models found")

    elif args.command == "download":
        if not args.model:
            print("Error: --model required for download")
            sys.exit(1)

        success = manager.download_model(args.model)
        if success:
            print(f"\nModel '{args.model}' downloaded successfully")
        else:
            print(f"\nModel '{args.model}' download failed")
            sys.exit(1)

    elif args.command == "status":
        status = manager.get_status()
        print(json.dumps(status, indent=2))

    elif args.command == "health":
        health = manager.check_health()
        print(json.dumps(health, indent=2))

    elif args.command == "recommend":
        if not args.task:
            print("Error: --task required for recommendation")
            sys.exit(1)

        model_id = manager.recommend_model(args.task)
        if model_id:
            model_info = manager.get_model_info(model_id)
            print(f"Recommended model for '{args.task}':")
            print(f"  ID: {model_id}")
            print(f"  Name: {model_info.get('display_name', model_id)}")
            print(f"  Runtime: {model_info.get('runtime', 'unknown')}")
            print(f"  Size: {model_info.get('size_gb', 'unknown')} GB")
            print(f"  Capabilities: {', '.join(model_info.get('capabilities', []))}")
        else:
            print(f"No model recommendation available for task '{args.task}'")


if __name__ == "__main__":
    main()
