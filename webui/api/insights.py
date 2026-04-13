#!/usr/bin/env python3
"""
ai-colab Insights API (P24.3)
Generates actionable recommendations based on agent performance data.

Endpoints:
    GET /api/insights/summary          — Fleet-wide insights summary
    GET /api/insights/agents           — Per-agent insights
    GET /api/insights/routing          — Task routing recommendations
    GET /api/insights/cost             — Cost optimization suggestions
    GET /api/insights/capacity         — Capacity planning recommendations
"""

import json
import os
import time
from pathlib import Path
from typing import Any, Dict, List

from flask import Blueprint, jsonify

insights_bp = Blueprint("insights", __name__)

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = SCRIPT_DIR
BLACKBOARD_DB = PROJECT_ROOT / ".ai-colab" / "blackboard.db"
ANALYTICS_DB = PROJECT_ROOT / ".ai-colab" / "analytics.db"


# ============================================================
# Database Helpers
# ============================================================

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
# Insight Generation
# ============================================================

def generate_agent_insights() -> List[Dict[str, Any]]:
    """Generate per-agent insights based on performance data."""
    insights = []

    # Get agent health data
    health_data = blackboard_list("fleet_health_")
    for key, health_json in health_data:
        try:
            health = json.loads(health_json)
            agent_name = key.replace("fleet_health_", "")

            agent_insight = {
                "agent": agent_name,
                "status": health.get("status", "unknown"),
                "recommendations": [],
                "warnings": [],
            }

            # Check for stale heartbeat
            last_ts = health.get("ts", 0)
            now = int(time.time())
            if now - last_ts > 60:
                agent_insight["warnings"].append({
                    "type": "stale_heartbeat",
                    "message": f"Agent heartbeat stale ({now - last_ts}s ago)",
                    "severity": "warning",
                })

            # Check for error status
            if health.get("status") in ("error", "crashed"):
                agent_insight["warnings"].append({
                    "type": "agent_error",
                    "message": f"Agent in {health.get('status')} state",
                    "severity": "critical",
                })
                agent_insight["recommendations"].append({
                    "type": "restart_agent",
                    "message": "Consider restarting the agent",
                    "priority": "high",
                })

            # Check conductor status
            conductor_json = blackboard_get(f"agent_conductor_status_{agent_name}")
            if conductor_json:
                conductor = json.loads(conductor_json)
                if conductor.get("conductor_status") in ("stale", "no_heartbeat"):
                    agent_insight["warnings"].append({
                        "type": "conductor_unreachable",
                        "message": f"Conductor {conductor.get('conductor_status')}",
                        "severity": "critical",
                    })

            # Get progress data
            progress_json = blackboard_get(f"agent_progress_{agent_name}")
            if progress_json:
                progress = json.loads(progress_json)
                pct = progress.get("pct", 0)
                if pct == 0:
                    agent_insight["recommendations"].append({
                        "type": "check_task_assignment",
                        "message": "Agent has 0% progress — check task assignment",
                        "priority": "medium",
                    })
                elif pct > 90:
                    agent_insight["recommendations"].append({
                        "type": "task_nearing_completion",
                        "message": f"Task {pct}% complete — monitor for completion",
                        "priority": "low",
                    })

            insights.append(agent_insight)
        except (json.JSONDecodeError, KeyError):
            continue

    return insights


def generate_routing_recommendations() -> List[Dict[str, Any]]:
    """Generate task routing recommendations based on historical success."""
    recommendations = []

    conn = get_analytics_db()
    if not conn:
        return [{"message": "Analytics database not available", "priority": "info"}]

    try:
        # Get agent success rates
        cursor = conn.execute("""
            SELECT agent_name,
                   SUM(tasks_completed) as completed,
                   SUM(tasks_failed) as failed,
                   SUM(tasks_completed + tasks_failed) as total
            FROM agent_metrics
            GROUP BY agent_name
            HAVING total > 0
            ORDER BY CAST(SUM(tasks_completed) AS FLOAT) / total DESC
        """)

        agents = [dict(row) for row in cursor.fetchall()]

        if not agents:
            return [{"message": "No historical data available", "priority": "info"}]

        # Recommend best performing agent
        best = agents[0]
        best_rate = best["completed"] / best["total"] if best["total"] > 0 else 0
        recommendations.append({
            "type": "preferred_agent",
            "message": f"{best['agent_name']} has {best_rate:.0%} success rate ({best['completed']}/{best['total']} tasks)",
            "agent": best["agent_name"],
            "priority": "medium",
        })

        # Recommend avoiding worst performing agent
        worst = agents[-1]
        worst_rate = worst["completed"] / worst["total"] if worst["total"] > 0 else 0
        if worst_rate < 0.7 and worst["total"] >= 3:
            recommendations.append({
                "type": "avoid_agent",
                "message": f"{worst['agent_name']} has {worst_rate:.0%} success rate — consider reassigning tasks",
                "agent": worst["agent_name"],
                "priority": "high",
            })

        # Recommend load balancing if one agent has significantly more tasks
        if len(agents) > 1:
            max_tasks = max(a["total"] for a in agents)
            min_tasks = min(a["total"] for a in agents)
            if max_tasks > min_tasks * 2:
                recommendations.append({
                    "type": "load_balance",
                    "message": "Task distribution is uneven — consider load balancing",
                    "priority": "medium",
                })

    except Exception:
        recommendations.append({"message": "Failed to generate routing recommendations", "priority": "info"})
    finally:
        conn.close()

    return recommendations


def generate_cost_recommendations() -> List[Dict[str, Any]]:
    """Generate cost optimization suggestions."""
    recommendations = []

    conn = get_analytics_db()
    if not conn:
        return [{"message": "Analytics database not available", "priority": "info"}]

    try:
        # Get per-agent cost data
        cursor = conn.execute("""
            SELECT agent_name, SUM(cost_usd) as total_cost, SUM(tokens_used) as total_tokens
            FROM agent_metrics
            GROUP BY agent_name
            HAVING total_cost > 0
            ORDER BY total_cost DESC
        """)

        agents = [dict(row) for row in cursor.fetchall()]

        if not agents:
            return [{"message": "No cost data available", "priority": "info"}]

        total_cost = sum(a["total_cost"] for a in agents)

        # Flag highest cost agent
        if agents:
            highest = agents[0]
            recommendations.append({
                "type": "highest_cost",
                "message": f"{highest['agent_name']} accounts for {highest['total_cost']:.2f} ({highest['total_cost']/total_cost:.0%} of total)",
                "priority": "medium",
            })

        # Recommend cheaper alternatives if available
        if len(agents) > 1:
            cheapest = agents[-1]
            most_expensive = agents[0]
            if most_expensive["total_cost"] > cheapest["total_cost"] * 3:
                recommendations.append({
                    "type": "cost_alternative",
                    "message": f"Consider using {cheapest['agent_name']} (${cheapest['total_cost']:.2f}) instead of {most_expensive['agent_name']} (${most_expensive['total_cost']:.2f}) for suitable tasks",
                    "priority": "medium",
                })

    except Exception:
        recommendations.append({"message": "Failed to generate cost recommendations", "priority": "info"})
    finally:
        conn.close()

    return recommendations


def generate_capacity_recommendations() -> List[Dict[str, Any]]:
    """Generate capacity planning suggestions."""
    recommendations = []

    health_data = blackboard_list("fleet_health_")
    total_agents = len(health_data)

    if total_agents == 0:
        return [{"message": "No agents detected", "priority": "info"}]

    # Count active agents
    active = 0
    for key, health_json in health_data:
        try:
            health = json.loads(health_json)
            if health.get("status") in ("ready", "busy"):
                active += 1
        except (json.JSONDecodeError, KeyError):
            continue

    # Capacity recommendations
    if active == 0:
        recommendations.append({
            "type": "no_active_agents",
            "message": "No active agents — consider starting at least one agent",
            "priority": "critical",
        })
    elif active < 2:
        recommendations.append({
            "type": "low_capacity",
            "message": f"Only {active} active agent — consider adding more for redundancy",
            "priority": "high",
        })
    elif total_agents > active:
        idle = total_agents - active
        recommendations.append({
            "type": "idle_agents",
            "message": f"{idle} idle agent(s) — consider reassigning or stopping",
            "priority": "low",
        })

    return recommendations


# ============================================================
# API Endpoints
# ============================================================

@insights_bp.route("/api/insights/summary")
def insights_summary():
    """Fleet-wide insights summary."""
    agent_insights = generate_agent_insights()
    capacity = generate_capacity_recommendations()

    total_warnings = sum(len(i.get("warnings", [])) for i in agent_insights)
    total_recommendations = sum(len(i.get("recommendations", [])) for i in agent_insights)

    return jsonify({
        "agents_monitored": len(agent_insights),
        "total_warnings": total_warnings,
        "total_recommendations": total_recommendations,
        "capacity": capacity,
        "timestamp": int(time.time()),
    })


@insights_bp.route("/api/insights/agents")
def insights_agents():
    """Per-agent insights."""
    insights = generate_agent_insights()
    return jsonify({"agents": insights, "count": len(insights)})


@insights_bp.route("/api/insights/routing")
def insights_routing():
    """Task routing recommendations."""
    recommendations = generate_routing_recommendations()
    return jsonify({"recommendations": recommendations})


@insights_bp.route("/api/insights/cost")
def insights_cost():
    """Cost optimization suggestions."""
    recommendations = generate_cost_recommendations()
    return jsonify({"recommendations": recommendations})


@insights_bp.route("/api/insights/capacity")
def insights_capacity():
    """Capacity planning recommendations."""
    recommendations = generate_capacity_recommendations()
    return jsonify({"recommendations": recommendations})
