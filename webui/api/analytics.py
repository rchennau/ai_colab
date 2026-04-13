#!/usr/bin/env python3
"""
ai-colab Analytics API (P24.1)
Exposes historical agent performance data via Web API endpoints.

Endpoints:
    GET /api/analytics/summary           — Fleet-wide performance summary
    GET /api/analytics/agents            — Per-agent performance metrics
    GET /api/analytics/agent/<name>      — Detailed metrics for specific agent
    GET /api/analytics/tasks             — Task completion history
    GET /api/analytics/errors            — Error distribution by type
    GET /api/analytics/cost              — Cost efficiency metrics
    GET /api/analytics/trends?days=7     — Historical trends (default 7 days)
"""

import json
import os
import sqlite3
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

from flask import Blueprint, jsonify, request

analytics_bp = Blueprint("analytics", __name__)

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = SCRIPT_DIR
BLACKBOARD_DB = PROJECT_ROOT / ".ai-colab" / "blackboard.db"
HCOM_DB = PROJECT_ROOT / ".hcom" / "hcom.db"
ANALYTICS_DB = PROJECT_ROOT / ".ai-colab" / "analytics.db"


# ============================================================
# Database Helpers
# ============================================================

def get_blackboard_db() -> Optional[sqlite3.Connection]:
    """Get blackboard database connection."""
    db_path = os.environ.get("BLACKBOARD_DB_PATH", str(BLACKBOARD_DB))
    if not Path(db_path).exists():
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception:
        return None


def get_hcom_db() -> Optional[sqlite3.Connection]:
    """Get hcom database connection."""
    db_path = str(HCOM_DB)
    if not Path(db_path).exists():
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception:
        return None


def get_analytics_db() -> sqlite3.Connection:
    """Get or create analytics database connection."""
    db_path = str(ANALYTICS_DB)
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    # Create tables if they don't exist
    conn.execute("""
        CREATE TABLE IF NOT EXISTS agent_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_name TEXT NOT NULL,
            ts INTEGER NOT NULL,
            tasks_completed INTEGER DEFAULT 0,
            tasks_failed INTEGER DEFAULT 0,
            avg_duration_ms INTEGER DEFAULT 0,
            error_count INTEGER DEFAULT 0,
            tokens_used INTEGER DEFAULT 0,
            cost_usd REAL DEFAULT 0.0
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS task_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_name TEXT NOT NULL,
            task_slug TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            completed_at INTEGER,
            duration_ms INTEGER,
            error_type TEXT,
            error_detail TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS error_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            agent_name TEXT NOT NULL,
            ts INTEGER NOT NULL,
            error_type TEXT NOT NULL,
            error_detail TEXT,
            track TEXT
        )
    """)

    conn.commit()
    return conn


def blackboard_get(key: str) -> str:
    """Get a value from the blackboard."""
    conn = get_blackboard_db()
    if not conn:
        return ""
    try:
        cursor = conn.execute(
            "SELECT value FROM kv WHERE key = ? AND (expires_at = 0 OR expires_at > ?)",
            (key, int(time.time()))
        )
        row = cursor.fetchone()
        return row["value"] if row else ""
    except Exception:
        return ""
    finally:
        conn.close()


def blackboard_list(prefix: str) -> List[tuple]:
    """List blackboard keys with a given prefix."""
    conn = get_blackboard_db()
    if not conn:
        return []
    try:
        cursor = conn.execute(
            "SELECT key, value FROM kv WHERE key LIKE ? AND (expires_at = 0 OR expires_at > ?)",
            (f"{prefix}%", int(time.time()))
        )
        return [(row["key"], row["value"]) for row in cursor.fetchall()]
    except Exception:
        return []
    finally:
        conn.close()


# ============================================================
# Data Collection
# ============================================================

def collect_agent_metrics() -> List[Dict[str, Any]]:
    """Collect current agent metrics from blackboard."""
    agents = []

    # Get agent health data
    health_data = blackboard_list("fleet_health_")
    for key, health_json in health_data:
        try:
            health = json.loads(health_json)
            agent_name = key.replace("fleet_health_", "")

            # Get progress data
            progress_json = blackboard_get(f"agent_progress_{agent_name}")
            progress = json.loads(progress_json) if progress_json else {}

            # Get conductor status
            conductor_json = blackboard_get(f"agent_conductor_status_{agent_name}")
            conductor_status = json.loads(conductor_json) if conductor_json else {}

            # Get protocol message
            protocol_json = blackboard_get(f"agent_protocol_{agent_name}")
            protocol = json.loads(protocol_json) if protocol_json else {}

            agents.append({
                "name": agent_name,
                "status": health.get("status", "unknown"),
                "progress": progress.get("pct", 0),
                "step": progress.get("step", "idle"),
                "track": progress.get("track", ""),
                "phase": progress.get("phase", ""),
                "last_ts": health.get("ts", 0),
                "latency_ms": health.get("latency_ms", 0),
                "conductor_status": conductor_status.get("conductor_status", "unknown"),
                "protocol_type": protocol.get("t", ""),
            })
        except (json.JSONDecodeError, KeyError):
            continue

    return agents


def collect_task_history(days: int = 7) -> List[Dict[str, Any]]:
    """Collect task history from analytics database."""
    conn = get_analytics_db()
    if not conn:
        return []

    cutoff = int(time.time()) - (days * 86400)
    try:
        cursor = conn.execute(
            "SELECT * FROM task_history WHERE started_at > ? ORDER BY started_at DESC LIMIT 100",
            (cutoff,)
        )
        return [dict(row) for row in cursor.fetchall()]
    except Exception:
        return []
    finally:
        conn.close()


def collect_error_distribution(days: int = 7) -> Dict[str, Any]:
    """Collect error distribution by type."""
    conn = get_analytics_db()
    if not conn:
        return {}

    cutoff = int(time.time()) - (days * 86400)
    try:
        cursor = conn.execute(
            "SELECT error_type, COUNT(*) as count FROM error_log WHERE ts > ? GROUP BY error_type ORDER BY count DESC",
            (cutoff,)
        )
        return {row["error_type"]: row["count"] for row in cursor.fetchall()}
    except Exception:
        return {}
    finally:
        conn.close()


def collect_cost_metrics() -> Dict[str, Any]:
    """Collect cost efficiency metrics."""
    conn = get_analytics_db()
    if not conn:
        return {"total_cost": 0, "total_tokens": 0, "agents": {}}

    try:
        # Total metrics
        cursor = conn.execute(
            "SELECT SUM(tokens_used) as total_tokens, SUM(cost_usd) as total_cost FROM agent_metrics"
        )
        row = cursor.fetchone()
        total_tokens = row["total_tokens"] or 0
        total_cost = row["total_cost"] or 0.0

        # Per-agent metrics
        cursor = conn.execute(
            "SELECT agent_name, SUM(tokens_used) as tokens, SUM(cost_usd) as cost, SUM(tasks_completed) as completed FROM agent_metrics GROUP BY agent_name"
        )
        agents = {
            row["agent_name"]: {
                "tokens": row["tokens"] or 0,
                "cost": row["cost"] or 0.0,
                "tasks_completed": row["completed"] or 0,
            }
            for row in cursor.fetchall()
        }

        return {
            "total_cost": total_cost,
            "total_tokens": total_tokens,
            "agents": agents,
        }
    except Exception:
        return {"total_cost": 0, "total_tokens": 0, "agents": {}}
    finally:
        conn.close()


# ============================================================
# API Endpoints
# ============================================================

@analytics_bp.route("/api/analytics/summary")
def analytics_summary():
    """Fleet-wide performance summary."""
    agents = collect_agent_metrics()

    total_agents = len(agents)
    active_agents = sum(1 for a in agents if a["status"] in ("ready", "busy"))
    error_agents = sum(1 for a in agents if a["status"] in ("error", "crashed"))

    # Calculate average progress
    progresses = [a["progress"] for a in agents if a["progress"] > 0]
    avg_progress = sum(progresses) / len(progresses) if progresses else 0

    return jsonify({
        "total_agents": total_agents,
        "active_agents": active_agents,
        "error_agents": error_agents,
        "avg_progress": round(avg_progress, 1),
        "timestamp": int(time.time()),
    })


@analytics_bp.route("/api/analytics/agents")
def analytics_agents():
    """Per-agent performance metrics."""
    agents = collect_agent_metrics()
    return jsonify({"agents": agents, "count": len(agents)})


@analytics_bp.route("/api/analytics/agent/<agent_name>")
def analytics_agent(agent_name):
    """Detailed metrics for specific agent."""
    agents = collect_agent_metrics()
    agent = next((a for a in agents if a["name"] == agent_name), None)

    if not agent:
        return jsonify({"error": f"Agent {agent_name} not found"}), 404

    # Get historical metrics from analytics DB
    conn = get_analytics_db()
    historical = []
    if conn:
        try:
            cursor = conn.execute(
                "SELECT * FROM agent_metrics WHERE agent_name = ? ORDER BY ts DESC LIMIT 24",
                (agent_name,)
            )
            historical = [dict(row) for row in cursor.fetchall()]
        except Exception:
            pass
        finally:
            conn.close()

    agent["historical"] = historical
    return jsonify(agent)


@analytics_bp.route("/api/analytics/tasks")
def analytics_tasks():
    """Task completion history."""
    days = request.args.get("days", 7, type=int)
    tasks = collect_task_history(days=days)
    return jsonify({"tasks": tasks, "count": len(tasks), "days": days})


@analytics_bp.route("/api/analytics/errors")
def analytics_errors():
    """Error distribution by type."""
    days = request.args.get("days", 7, type=int)
    errors = collect_error_distribution(days=days)
    return jsonify({"errors": errors, "days": days})


@analytics_bp.route("/api/analytics/cost")
def analytics_cost():
    """Cost efficiency metrics."""
    cost = collect_cost_metrics()
    return jsonify(cost)


@analytics_bp.route("/api/analytics/trends")
def analytics_trends():
    """Historical trends."""
    days = request.args.get("days", 7, type=int)
    conn = get_analytics_db()

    if not conn:
        return jsonify({"error": "Analytics database not available"}), 500

    try:
        # Daily aggregation
        cutoff = int(time.time()) - (days * 86400)
        cursor = conn.execute("""
            SELECT
                DATE(ts, 'unixepoch') as day,
                SUM(tasks_completed) as completed,
                SUM(tasks_failed) as failed,
                AVG(avg_duration_ms) as avg_duration,
                SUM(error_count) as errors
            FROM agent_metrics
            WHERE ts > ?
            GROUP BY day
            ORDER BY day
        """, (cutoff,))

        trends = [dict(row) for row in cursor.fetchall()]
        return jsonify({"trends": trends, "days": days})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()
