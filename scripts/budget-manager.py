#!/usr/bin/env python3
"""
ai-colab Budget Manager (P5.3)
Tracks token usage, estimates costs, and manages budgets for LLM agents.

Features:
- Per-agent token usage tracking
- Cost estimation from provider pricing tables
- Budget configuration and enforcement
- Alert thresholds and spending caps
- Cost-aware routing recommendations

Usage:
    python3 budget-manager.py record --agent gemini --input-tokens 1000 --output-tokens 500
    python3 budget-manager.py status --agent gemini
    python3 budget-manager.py report --period daily
    python3 budget-manager.py set-budget --agent gemini --budget 100
    python3 budget-manager.py alerts
"""

import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
BUDGET_DIR = PROJECT_ROOT / ".ai-colab" / "budget"
BUDGET_DB = BUDGET_DIR / "budget.db"
PRICING_FILE = PROJECT_ROOT / "config" / "pricing.json"
BUDGET_CONFIG_FILE = PROJECT_ROOT / "config" / "budget-config.json"

# Default budget configuration
DEFAULT_BUDGET_CONFIG = {
    "global_monthly_budget": 1000.00,
    "alert_thresholds": [50, 75, 90, 100],
    "agents": {},
}

# Default pricing (fallback if pricing.json not found)
DEFAULT_PRICING = {
    "providers": {
        "gemini": {
            "display_name": "Google Gemini",
            "models": {"default": {"input_per_million": 3.50, "output_per_million": 10.50}},
        },
        "claude": {
            "display_name": "Anthropic Claude",
            "models": {"default": {"input_per_million": 3.00, "output_per_million": 15.00}},
        },
        "qwen": {
            "display_name": "Alibaba Qwen",
            "models": {"default": {"input_per_million": 0.50, "output_per_million": 2.00}},
        },
        "deepseek": {
            "display_name": "DeepSeek",
            "models": {"default": {"input_per_million": 0.27, "output_per_million": 1.10}},
        },
    },
    "defaults": {
        "default_provider": "gemini",
        "default_model": "default",
        "avg_token_per_char": 0.25,
        "currency": "USD",
    },
}


class BudgetManager:
    """Manages token tracking, cost estimation, and budget enforcement."""

    def __init__(self):
        self.pricing = self._load_pricing()
        self.budget_config = self._load_budget_config()
        self._ensure_db()

    def _load_pricing(self) -> Dict[str, Any]:
        """Load pricing configuration."""
        if PRICING_FILE.exists():
            with open(PRICING_FILE) as f:
                return json.load(f)
        return DEFAULT_PRICING

    def _load_budget_config(self) -> Dict[str, Any]:
        """Load budget configuration."""
        if BUDGET_CONFIG_FILE.exists():
            with open(BUDGET_CONFIG_FILE) as f:
                return json.load(f)
        return DEFAULT_BUDGET_CONFIG

    def _ensure_db(self):
        """Create database and tables if they don't exist."""
        BUDGET_DIR.mkdir(parents=True, exist_ok=True)

        self.conn = sqlite3.connect(str(BUDGET_DB))
        self.conn.row_factory = sqlite3.Row
        cursor = self.conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS usage (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL,
                provider TEXT NOT NULL,
                model TEXT NOT NULL,
                input_tokens INTEGER NOT NULL,
                output_tokens INTEGER NOT NULL,
                estimated_cost REAL NOT NULL,
                timestamp REAL NOT NULL,
                task_id TEXT DEFAULT '',
                metadata TEXT DEFAULT '{}'
            )
        """)

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_usage_agent
            ON usage(agent, timestamp)
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS budgets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL UNIQUE,
                monthly_budget REAL NOT NULL,
                alert_thresholds TEXT DEFAULT '[50,75,90,100]',
                enabled INTEGER DEFAULT 1,
                created_at REAL NOT NULL
            )
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL,
                threshold INTEGER NOT NULL,
                current_spend REAL NOT NULL,
                budget REAL NOT NULL,
                timestamp REAL NOT NULL,
                message TEXT NOT NULL
            )
        """)

        self.conn.commit()

    def estimate_cost(self, agent: str, input_tokens: int, output_tokens: int) -> float:
        """Estimate cost for token usage."""
        # Determine provider from agent name
        provider = self._get_provider_for_agent(agent)

        # Get pricing for provider
        provider_config = self.pricing.get("providers", {}).get(provider, {})
        models = provider_config.get("models", {})

        # Use first model's pricing (or default)
        model_name = list(models.keys())[0] if models else "default"
        model_pricing = models.get(model_name, {})

        input_cost = (input_tokens / 1_000_000) * model_pricing.get("input_per_million", 0)
        output_cost = (output_tokens / 1_000_000) * model_pricing.get("output_per_million", 0)

        return round(input_cost + output_cost, 6)

    def record_usage(
        self,
        agent: str,
        input_tokens: int,
        output_tokens: int,
        provider: Optional[str] = None,
        model: Optional[str] = None,
        task_id: str = "",
        metadata: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """Record token usage and estimate cost."""
        provider = provider or self._get_provider_for_agent(agent)
        model = model or "default"

        cost = self.estimate_cost(agent, input_tokens, output_tokens)

        cursor = self.conn.cursor()
        cursor.execute(
            """
            INSERT INTO usage (agent, provider, model, input_tokens, output_tokens, estimated_cost, timestamp, task_id, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                agent,
                provider,
                model,
                input_tokens,
                output_tokens,
                cost,
                time.time(),
                task_id,
                json.dumps(metadata or {}),
            ),
        )
        self.conn.commit()

        # Check budget alerts
        self._check_budget_alerts(agent)

        return {
            "agent": agent,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "estimated_cost": cost,
            "provider": provider,
        }

    def get_usage(
        self,
        agent: str,
        period: str = "daily",
        start_time: Optional[float] = None,
        end_time: Optional[float] = None,
    ) -> Dict[str, Any]:
        """Get usage statistics for an agent."""
        cursor = self.conn.cursor()

        # Calculate time range
        now = time.time()
        if period == "daily":
            start = now - 86400
        elif period == "weekly":
            start = now - 604800
        elif period == "monthly":
            start = now - 2592000
        else:
            start = start_time or 0

        end = end_time or now

        # Query usage
        cursor.execute(
            """
            SELECT
                SUM(input_tokens) as total_input,
                SUM(output_tokens) as total_output,
                SUM(estimated_cost) as total_cost,
                COUNT(*) as request_count
            FROM usage
            WHERE agent = ? AND timestamp BETWEEN ? AND ?
            """,
            (agent, start, end),
        )
        row = cursor.fetchone()

        return {
            "agent": agent,
            "period": period,
            "total_input_tokens": row["total_input"] or 0,
            "total_output_tokens": row["total_output"] or 0,
            "total_cost": round(row["total_cost"] or 0, 4),
            "request_count": row["request_count"] or 0,
        }

    def get_all_usage(self, period: str = "daily") -> List[Dict[str, Any]]:
        """Get usage statistics for all agents."""
        cursor = self.conn.cursor()

        now = time.time()
        if period == "daily":
            start = now - 86400
        elif period == "weekly":
            start = now - 604800
        elif period == "monthly":
            start = now - 2592000
        else:
            start = 0

        cursor.execute(
            """
            SELECT
                agent,
                SUM(input_tokens) as total_input,
                SUM(output_tokens) as total_output,
                SUM(estimated_cost) as total_cost,
                COUNT(*) as request_count
            FROM usage
            WHERE timestamp BETWEEN ? AND ?
            GROUP BY agent
            ORDER BY total_cost DESC
            """,
            (start, now),
        )

        results = []
        for row in cursor.fetchall():
            results.append({
                "agent": row["agent"],
                "total_input_tokens": row["total_input"] or 0,
                "total_output_tokens": row["total_output"] or 0,
                "total_cost": round(row["total_cost"] or 0, 4),
                "request_count": row["request_count"] or 0,
            })

        return results

    def set_budget(self, agent: str, monthly_budget: float, thresholds: Optional[List[int]] = None):
        """Set budget for an agent."""
        cursor = self.conn.cursor()
        thresholds = thresholds or self.budget_config.get("alert_thresholds", [50, 75, 90, 100])

        cursor.execute(
            """
            INSERT OR REPLACE INTO budgets (agent, monthly_budget, alert_thresholds, enabled, created_at)
            VALUES (?, ?, ?, 1, ?)
            """,
            (agent, monthly_budget, json.dumps(thresholds), time.time()),
        )
        self.conn.commit()

    def get_budget_status(self, agent: str) -> Dict[str, Any]:
        """Get budget status for an agent."""
        cursor = self.conn.cursor()

        # Get budget
        cursor.execute("SELECT * FROM budgets WHERE agent = ?", (agent,))
        budget_row = cursor.fetchone()

        if not budget_row:
            return {
                "agent": agent,
                "budget": None,
                "spent": 0,
                "remaining": None,
                "percentage": 0,
                "enabled": False,
            }

        # Get current month's spending
        now = time.time()
        month_start = now - 2592000

        cursor.execute(
            """
            SELECT SUM(estimated_cost) as total_cost
            FROM usage
            WHERE agent = ? AND timestamp BETWEEN ? AND ?
            """,
            (agent, month_start, now),
        )
        spent = cursor.fetchone()["total_cost"] or 0

        budget = budget_row["monthly_budget"]
        remaining = max(0, budget - spent)
        percentage = (spent / budget * 100) if budget > 0 else 0

        return {
            "agent": agent,
            "budget": budget,
            "spent": round(spent, 4),
            "remaining": round(remaining, 4),
            "percentage": round(percentage, 1),
            "enabled": bool(budget_row["enabled"]),
        }

    def get_alerts(self, agent: Optional[str] = None, limit: int = 20) -> List[Dict[str, Any]]:
        """Get budget alerts."""
        cursor = self.conn.cursor()

        if agent:
            cursor.execute(
                """
                SELECT * FROM alerts
                WHERE agent = ?
                ORDER BY timestamp DESC
                LIMIT ?
                """,
                (agent, limit),
            )
        else:
            cursor.execute(
                """
                SELECT * FROM alerts
                ORDER BY timestamp DESC
                LIMIT ?
                """,
                (limit,),
            )

        return [dict(row) for row in cursor.fetchall()]

    def get_cost_efficiency_ranking(self, period: str = "monthly") -> List[Dict[str, Any]]:
        """Get agents ranked by cost efficiency (cost per request)."""
        usage_data = self.get_all_usage(period)

        for agent_data in usage_data:
            if agent_data["request_count"] > 0:
                agent_data["cost_per_request"] = round(
                    agent_data["total_cost"] / agent_data["request_count"], 4
                )
            else:
                agent_data["cost_per_request"] = 0

        return sorted(usage_data, key=lambda x: x["cost_per_request"])

    def _get_provider_for_agent(self, agent: str) -> str:
        """Determine provider from agent name."""
        agent_lower = agent.lower()
        if "gemini" in agent_lower:
            return "gemini"
        elif "claude" in agent_lower:
            return "claude"
        elif "qwen" in agent_lower:
            return "qwen"
        elif "deepseek" in agent_lower:
            return "deepseek"
        elif "nemo" in agent_lower or "nvidia" in agent_lower:
            return "nvidia"
        else:
            return self.pricing.get("defaults", {}).get("default_provider", "gemini")

    def _check_budget_alerts(self, agent: str):
        """Check and trigger budget alerts for an agent."""
        cursor = self.conn.cursor()

        # Get budget
        cursor.execute("SELECT * FROM budgets WHERE agent = ? AND enabled = 1", (agent,))
        budget_row = cursor.fetchone()

        if not budget_row:
            return

        budget = budget_row["monthly_budget"]
        thresholds = json.loads(budget_row["alert_thresholds"])

        # Get current spending
        now = time.time()
        month_start = now - 2592000

        cursor.execute(
            """
            SELECT SUM(estimated_cost) as total_cost
            FROM usage
            WHERE agent = ? AND timestamp BETWEEN ? AND ?
            """,
            (agent, month_start, now),
        )
        spent = cursor.fetchone()["total_cost"] or 0

        percentage = (spent / budget * 100) if budget > 0 else 0

        # Check thresholds
        for threshold in thresholds:
            if percentage >= threshold:
                # Check if alert already triggered for this threshold this month
                month_start_ts = month_start
                cursor.execute(
                    """
                    SELECT COUNT(*) FROM alerts
                    WHERE agent = ? AND threshold = ? AND timestamp BETWEEN ? AND ?
                    """,
                    (agent, threshold, month_start_ts, now),
                )
                if cursor.fetchone()[0] == 0:
                    # Trigger alert
                    message = f"Budget alert: {agent} has spent ${spent:.2f} of ${budget:.2f} ({percentage:.0f}%)"
                    cursor.execute(
                        """
                        INSERT INTO alerts (agent, threshold, current_spend, budget, timestamp, message)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        (agent, threshold, spent, budget, now, message),
                    )
                    self.conn.commit()
                    print(f"⚠️  BUDGET ALERT: {message}")

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()


def main():
    parser = argparse.ArgumentParser(description="ai-colab Budget Manager")
    parser.add_argument(
        "command",
        choices=["record", "status", "report", "set-budget", "alerts", "ranking", "help"],
        help="Command to execute",
    )
    parser.add_argument("--agent", help="Agent name")
    parser.add_argument("--input-tokens", type=int, help="Input token count")
    parser.add_argument("--output-tokens", type=int, help="Output token count")
    parser.add_argument("--provider", help="Provider name")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--budget", type=float, help="Monthly budget amount")
    parser.add_argument("--period", default="daily", choices=["daily", "weekly", "monthly"], help="Report period")
    parser.add_argument("--task-id", help="Task ID for tracking")

    args = parser.parse_args()

    if args.command == "help":
        parser.print_help()
        return

    if args.command in ["record", "status", "set-budget"] and not args.agent:
        print("Error: --agent required for this command")
        sys.exit(1)

    manager = BudgetManager()

    try:
        if args.command == "record":
            if not args.input_tokens or not args.output_tokens:
                print("Error: --input-tokens and --output-tokens required")
                sys.exit(1)

            result = manager.record_usage(
                agent=args.agent,
                input_tokens=args.input_tokens,
                output_tokens=args.output_tokens,
                provider=args.provider,
                model=args.model,
                task_id=args.task_id or "",
            )
            print(json.dumps(result, indent=2))

        elif args.command == "status":
            usage = manager.get_usage(args.agent, args.period)
            budget_status = manager.get_budget_status(args.agent)
            print(json.dumps({**usage, "budget": budget_status}, indent=2))

        elif args.command == "report":
            all_usage = manager.get_all_usage(args.period)
            total_cost = sum(u["total_cost"] for u in all_usage)
            total_requests = sum(u["request_count"] for u in all_usage)

            report = {
                "period": args.period,
                "total_cost": round(total_cost, 4),
                "total_requests": total_requests,
                "agents": all_usage,
            }
            print(json.dumps(report, indent=2))

        elif args.command == "set-budget":
            if not args.budget:
                print("Error: --budget required")
                sys.exit(1)

            manager.set_budget(args.agent, args.budget)
            print(f"Budget set for {args.agent}: ${args.budget:.2f}/month")

        elif args.command == "alerts":
            alerts = manager.get_alerts(agent=args.agent)
            if alerts:
                for alert in alerts:
                    print(f"{alert['message']}")
            else:
                print("No budget alerts")

        elif args.command == "ranking":
            ranking = manager.get_cost_efficiency_ranking(args.period)
            print(json.dumps(ranking, indent=2))

    finally:
        manager.close()


if __name__ == "__main__":
    main()
