#!/usr/bin/env python3
"""
ai-colab Agent Benchmark Runner (P4.5)
Executes standardized tasks against LLM CLI agents and collects metrics.

Usage:
    python3 benchmark-runner.py --agent gemini --tasks all
    python3 benchmark-runner.py --agent qwen --tasks coding_generate,coding_debug
    python3 benchmark-runner.py --agent claude --output results.json
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
TASKS_FILE = PROJECT_ROOT / "config" / "benchmark-tasks.json"
RESULTS_DIR = PROJECT_ROOT / "benchmark-results"


class TaskResult:
    """Result from a single benchmark task."""

    def __init__(self, task_id: str, agent: str):
        self.task_id = task_id
        self.agent = agent
        self.start_time = None
        self.end_time = None
        self.duration_seconds = 0
        self.output = ""
        self.error = ""
        self.score = 0
        self.max_score = 0
        self.criteria_passed = []
        self.criteria_failed = []
        self.exit_code = -1

    def to_dict(self) -> Dict[str, Any]:
        return {
            "task_id": self.task_id,
            "agent": self.agent,
            "duration_seconds": round(self.duration_seconds, 2),
            "score": self.score,
            "max_score": self.max_score,
            "score_percentage": round((self.score / self.max_score * 100) if self.max_score > 0 else 0, 1),
            "criteria_passed": len(self.criteria_passed),
            "criteria_failed": len(self.criteria_failed),
            "exit_code": self.exit_code,
            "error": self.error[:500] if self.error else "",
        }


class BenchmarkRunner:
    """Runs benchmark tasks against an agent."""

    def __init__(self, agent: str, tasks_file: Path = TASKS_FILE):
        self.agent = agent
        self.tasks = self._load_tasks(tasks_file)
        self.results: List[TaskResult] = []

    def _load_tasks(self, tasks_file: Path) -> Dict[str, Any]:
        """Load task definitions from JSON file."""
        if not tasks_file.exists():
            print(f"Error: Tasks file not found: {tasks_file}")
            sys.exit(1)

        with open(tasks_file) as f:
            config = json.load(f)

        return config.get("tasks", {})

    def run_task(self, task_id: str) -> TaskResult:
        """Execute a single benchmark task against the agent."""
        if task_id not in self.tasks:
            print(f"Error: Unknown task '{task_id}'")
            sys.exit(1)

        task = self.tasks[task_id]
        result = TaskResult(task_id, self.agent)

        print(f"\n{'='*60}")
        print(f"Task: {task['name']} ({task_id})")
        print(f"Category: {task['category']}")
        print(f"Timeout: {task.get('timeout_seconds', 120)}s")
        print(f"{'='*60}")

        # Execute the task
        result.start_time = time.time()

        try:
            # Build command based on agent type
            cmd = self._build_agent_command(task["prompt"], task.get("timeout_seconds", 120))

            if not cmd:
                result.error = f"Agent '{self.agent}' CLI not found"
                result.end_time = time.time()
                result.duration_seconds = result.end_time - result.start_time
                return result

            # Execute the agent
            process = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=task.get("timeout_seconds", 120),
                env=self._get_agent_env(),
            )

            result.output = process.stdout
            result.error = process.stderr
            result.exit_code = process.returncode

        except subprocess.TimeoutExpired:
            result.error = f"Task timed out after {task.get('timeout_seconds', 120)}s"
            result.exit_code = -1
        except Exception as e:
            result.error = str(e)
            result.exit_code = -1

        result.end_time = time.time()
        result.duration_seconds = result.end_time - result.start_time

        # Evaluate the result
        self._evaluate_task(result, task)

        return result

    def _build_agent_command(self, prompt: str, timeout: int) -> Optional[List[str]]:
        """Build the command to execute the agent with the given prompt."""
        agent_configs = {
            "gemini": {
                "bins": ["gemini", "gemini-cli"],
                "args": lambda p: ["--prompt", p],
            },
            "qwen": {
                "bins": ["qwen-code", "qwen", "qwen-cli"],
                "args": lambda p: ["--prompt", p],
            },
            "claude": {
                "bins": ["claude-code", "claude"],
                "args": lambda p: ["--prompt", p],
            },
            "deepseek": {
                "bins": ["deepseek-cli", "deepseek"],
                "args": lambda p: ["--prompt", p],
            },
        }

        config = agent_configs.get(self.agent)
        if not config:
            # Try to find any matching binary
            print(f"  Warning: Unknown agent '{self.agent}', trying as command...")
            return [self.agent, "--prompt", prompt]

        for bin_name in config["bins"]:
            # Find the binary
            try:
                result = subprocess.run(
                    ["which", bin_name],
                    capture_output=True,
                    text=True,
                )
                if result.returncode == 0:
                    cmd = [result.stdout.strip()] + config["args"](prompt)
                    print(f"  Using: {cmd[0]}")
                    return cmd
            except Exception:
                continue

        return None

    def _get_agent_env(self) -> Dict[str, str]:
        """Get environment variables for the agent."""
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"

        # Add API keys if available
        api_keys = {
            "GEMINI_API_KEY",
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            "DEEPSEEK_API_KEY",
            "QWEN_API_KEY",
            "NVIDIA_API_KEY",
        }
        for key in api_keys:
            if key in env:
                env[key] = env[key]

        return env

    def _evaluate_task(self, result: TaskResult, task: Dict[str, Any]):
        """Evaluate the task result against criteria."""
        eval_config = task.get("evaluation", {})
        eval_type = eval_config.get("type", "manual")
        criteria = eval_config.get("criteria", [])
        max_score = eval_config.get("max_score", len(criteria))

        result.max_score = max_score

        if not result.output and not result.error:
            result.score = 0
            result.criteria_failed = criteria
            return

        # Combine stdout and stderr for evaluation
        full_output = result.output + "\n" + result.error

        # Simple keyword-based evaluation
        for criterion in criteria:
            # Check if criterion keywords appear in the output
            criterion_lower = criterion.lower()

            # Special handling for code tasks
            if "correctly calculates" in criterion_lower or "returns" in criterion_lower:
                # Try to extract and verify specific values
                if "48" in criterion_lower and "48 km/h" in full_output:
                    result.criteria_passed.append(criterion)
                    result.score += 1
                    continue
                if "6" in criterion_lower and "[-2,1,-3,4,-1,2,1,-5,4]" in task.get("prompt", ""):
                    # Check if output contains the correct answer
                    if "6" in full_output and ("subarray" in full_output.lower() or "sum" in full_output.lower()):
                        result.criteria_passed.append(criterion)
                        result.score += 1
                        continue

            # General keyword matching
            keywords = [w for w in criterion_lower.split() if len(w) > 3]
            if all(kw in full_output.lower() for kw in keywords[:3]):
                result.criteria_passed.append(criterion)
                result.score += 1
            else:
                result.criteria_failed.append(criterion)

        print(f"\n  Score: {result.score}/{max_score} ({result.score/max_score*100:.0f}%)")
        print(f"  Time: {result.duration_seconds:.1f}s")

    def run_all(self, task_ids: Optional[List[str]] = None) -> List[TaskResult]:
        """Run all or specified tasks."""
        if task_ids is None:
            task_ids = list(self.tasks.keys())

        print(f"\nRunning {len(task_ids)} tasks against agent: {self.agent}")

        for task_id in task_ids:
            result = self.run_task(task_id)
            self.results.append(result)

        return self.results

    def generate_report(self) -> Dict[str, Any]:
        """Generate a summary report of all results."""
        if not self.results:
            return {"error": "No results to report"}

        total_score = sum(r.score for r in self.results)
        total_max = sum(r.max_score for r in self.results)
        avg_duration = sum(r.duration_seconds for r in self.results) / len(self.results)

        # Group by category
        categories = {}
        for r in self.results:
            task = self.tasks.get(r.task_id, {})
            cat = task.get("category", "unknown")
            if cat not in categories:
                categories[cat] = {"score": 0, "max": 0, "count": 0, "tasks": []}
            categories[cat]["score"] += r.score
            categories[cat]["max"] += r.max_score
            categories[cat]["count"] += 1
            categories[cat]["tasks"].append(r.to_dict())

        report = {
            "agent": self.agent,
            "timestamp": datetime.now().isoformat(),
            "overall": {
                "score": total_score,
                "max_score": total_max,
                "percentage": round(total_score / total_max * 100, 1) if total_max > 0 else 0,
                "tasks_completed": len([r for r in self.results if r.exit_code == 0]),
                "tasks_failed": len([r for r in self.results if r.exit_code != 0]),
                "avg_duration_seconds": round(avg_duration, 2),
                "total_duration_seconds": round(sum(r.duration_seconds for r in self.results), 2),
            },
            "categories": categories,
            "results": [r.to_dict() for r in self.results],
        }

        return report


def main():
    parser = argparse.ArgumentParser(description="ai-colab Agent Benchmark Runner")
    parser.add_argument("--agent", required=True, help="Agent name (gemini, qwen, claude, deepseek)")
    parser.add_argument("--tasks", default="all", help="Comma-separated task IDs or 'all'")
    parser.add_argument("--output", help="Output file path for results JSON")
    parser.add_argument("--tasks-file", help="Path to benchmark tasks JSON file")

    args = parser.parse_args()

    tasks_file = Path(args.tasks_file) if args.tasks_file else TASKS_FILE

    runner = BenchmarkRunner(args.agent, tasks_file)

    # Determine which tasks to run
    if args.tasks == "all":
        task_ids = list(runner.tasks.keys())
    else:
        task_ids = [t.strip() for t in args.tasks.split(",")]

    # Run benchmarks
    results = runner.run_all(task_ids)

    # Generate report
    report = runner.generate_report()

    # Print summary
    overall = report["overall"]
    print(f"\n{'='*60}")
    print(f"BENCHMARK REPORT: {args.agent}")
    print(f"{'='*60}")
    print(f"Overall Score: {overall['score']}/{overall['max_score']} ({overall['percentage']}%)")
    print(f"Tasks Completed: {overall['tasks_completed']}/{len(results)}")
    print(f"Tasks Failed: {overall['tasks_failed']}/{len(results)}")
    print(f"Average Duration: {overall['avg_duration_seconds']:.1f}s")
    print(f"Total Duration: {overall['total_duration_seconds']:.1f}s")

    for cat_name, cat_data in report["categories"].items():
        cat_pct = round(cat_data["score"] / cat_data["max"] * 100, 1) if cat_data["max"] > 0 else 0
        print(f"  {cat_name}: {cat_data['score']}/{cat_data['max']} ({cat_pct}%)")

    # Save results
    output_path = args.output
    if not output_path:
        RESULTS_DIR.mkdir(exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = RESULTS_DIR / f"benchmark_{args.agent}_{timestamp}.json"

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nResults saved to: {output_path}")

    # Exit with appropriate code
    if overall["tasks_failed"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
