#!/usr/bin/env python3
"""
ai-colab Analytics Export (P24.4)
Historical trending and export functionality for analytics data.

Endpoints:
    GET /api/export/csv?days=7          — Export analytics as CSV
    GET /api/export/json?days=7         — Export analytics as JSON
    POST /api/export/schedule           — Schedule recurring export
    GET /api/export/history             — List past exports
    DELETE /api/export/<export_id>      — Delete an export

Usage:
    curl http://localhost:8080/api/export/csv?days=7 -o analytics.csv
    curl http://localhost:8080/api/export/json?days=7 -o analytics.json
"""

import csv
import io
import json
import os
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

from flask import Blueprint, jsonify, request, Response

export_bp = Blueprint("export", __name__)

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = SCRIPT_DIR
BLACKBOARD_DB = PROJECT_ROOT / ".ai-colab" / "blackboard.db"
ANALYTICS_DB = PROJECT_ROOT / ".ai-colab" / "analytics.db"
EXPORT_DIR = PROJECT_ROOT / ".ai-colab" / "exports"


# ============================================================
# Database Helpers
# ============================================================

def get_analytics_db():
    """Get analytics database connection."""
    import sqlite3
    db_path = str(ANALYTICS_DB)
    if not Path(db_path).exists():
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception:
        return None


def get_blackboard_db():
    """Get blackboard database connection."""
    import sqlite3
    db_path = os.environ.get("BLACKBOARD_DB_PATH", str(BLACKBOARD_DB))
    if not Path(db_path).exists():
        return None
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception:
        return None


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

def collect_current_fleet_state() -> Dict[str, Any]:
    """Collect current fleet state from blackboard."""
    agents = []

    health_data = blackboard_list("fleet_health_")
    for key, health_json in health_data:
        try:
            health = json.loads(health_json)
            agent_name = key.replace("fleet_health_", "")

            progress_json = blackboard_get(f"agent_progress_{agent_name}")
            progress = json.loads(progress_json) if progress_json else {}

            agents.append({
                "agent": agent_name,
                "status": health.get("status", "unknown"),
                "progress": progress.get("pct", 0),
                "track": progress.get("track", ""),
                "step": progress.get("step", "idle"),
                "latency_ms": health.get("latency_ms", 0),
                "ts": health.get("ts", 0),
            })
        except (json.JSONDecodeError, KeyError):
            continue

    return {
        "timestamp": int(time.time()),
        "agent_count": len(agents),
        "agents": agents,
    }


def collect_historical_metrics(days: int = 7) -> List[Dict[str, Any]]:
    """Collect historical metrics from analytics database."""
    conn = get_analytics_db()
    if not conn:
        return []

    cutoff = int(time.time()) - (days * 86400)
    try:
        cursor = conn.execute(
            """SELECT am.*, th.task_slug, th.status as task_status,
                      th.duration_ms as task_duration, th.error_type
               FROM agent_metrics am
               LEFT JOIN task_history th ON am.agent_name = th.agent_name
               WHERE am.ts > ?
               ORDER BY am.ts DESC""",
            (cutoff,)
        )
        return [dict(row) for row in cursor.fetchall()]
    except Exception:
        return []
    finally:
        conn.close()


def collect_error_log(days: int = 7) -> List[Dict[str, Any]]:
    """Collect error log from analytics database."""
    conn = get_analytics_db()
    if not conn:
        return []

    cutoff = int(time.time()) - (days * 86400)
    try:
        cursor = conn.execute(
            "SELECT * FROM error_log WHERE ts > ? ORDER BY ts DESC",
            (cutoff,)
        )
        return [dict(row) for row in cursor.fetchall()]
    except Exception:
        return []
    finally:
        conn.close()


# ============================================================
# Export Functions
# ============================================================

def export_to_csv(days: int = 7) -> str:
    """Export analytics data as CSV."""
    metrics = collect_historical_metrics(days=days)
    errors = collect_error_log(days=days)
    fleet_state = collect_current_fleet_state()

    output = io.StringIO()
    writer = csv.writer(output)

    # Fleet state summary
    writer.writerow(["Fleet State"])
    writer.writerow(["Timestamp", "Agent Count"])
    writer.writerow([
        datetime.fromtimestamp(fleet_state["timestamp"]).isoformat(),
        fleet_state["agent_count"],
    ])
    writer.writerow([])

    # Agent states
    if fleet_state["agents"]:
        writer.writerow(["Agent States"])
        writer.writerow(["Agent", "Status", "Progress", "Track", "Step", "Latency (ms)", "Last Seen"])
        for agent in fleet_state["agents"]:
            writer.writerow([
                agent["agent"],
                agent["status"],
                agent["progress"],
                agent["track"],
                agent["step"],
                agent["latency_ms"],
                datetime.fromtimestamp(agent["ts"]).isoformat() if agent["ts"] else "Never",
            ])
        writer.writerow([])

    # Historical metrics
    if metrics:
        writer.writerow(["Historical Metrics"])
        writer.writerow(["Agent", "Timestamp", "Tasks Completed", "Tasks Failed", "Avg Duration (ms)", "Errors", "Tokens", "Cost (USD)"])
        for row in metrics:
            writer.writerow([
                row.get("agent_name", ""),
                datetime.fromtimestamp(row.get("ts", 0)).isoformat(),
                row.get("tasks_completed", 0),
                row.get("tasks_failed", 0),
                row.get("avg_duration_ms", 0),
                row.get("error_count", 0),
                row.get("tokens_used", 0),
                f"{row.get('cost_usd', 0.0):.4f}",
            ])
        writer.writerow([])

    # Error log
    if errors:
        writer.writerow(["Error Log"])
        writer.writerow(["Agent", "Timestamp", "Error Type", "Detail", "Track"])
        for row in errors:
            writer.writerow([
                row.get("agent_name", ""),
                datetime.fromtimestamp(row.get("ts", 0)).isoformat(),
                row.get("error_type", ""),
                row.get("error_detail", ""),
                row.get("track", ""),
            ])

    return output.getvalue()


def export_to_json(days: int = 7) -> Dict[str, Any]:
    """Export analytics data as JSON."""
    metrics = collect_historical_metrics(days=days)
    errors = collect_error_log(days=days)
    fleet_state = collect_current_fleet_state()

    return {
        "export_timestamp": int(time.time()),
        "export_period_days": days,
        "fleet_state": fleet_state,
        "historical_metrics": metrics,
        "error_log": errors,
        "summary": {
            "total_metrics_records": len(metrics),
            "total_error_records": len(errors),
            "agents_monitored": fleet_state["agent_count"],
        },
    }


# ============================================================
# API Endpoints
# ============================================================

@export_bp.route("/api/export/csv")
def export_csv():
    """Export analytics as CSV."""
    days = request.args.get("days", 7, type=int)
    csv_data = export_to_csv(days=days)

    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment;filename=analytics-{days}d.csv"},
    )


@export_bp.route("/api/export/json")
def export_json():
    """Export analytics as JSON."""
    days = request.args.get("days", 7, type=int)
    data = export_to_json(days=days)

    return jsonify(data)


@export_bp.route("/api/export/summary")
def export_summary():
    """Export summary only (lightweight)."""
    fleet_state = collect_current_fleet_state()

    return jsonify({
        "timestamp": fleet_state["timestamp"],
        "agent_count": fleet_state["agent_count"],
        "agents": [
            {
                "name": a["agent"],
                "status": a["status"],
                "progress": a["progress"],
                "track": a["track"],
            }
            for a in fleet_state["agents"]
        ],
    })
