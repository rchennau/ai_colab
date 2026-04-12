#!/usr/bin/env python3
"""
ai-colab Conductor Protocol Handler (P6.3)
Processes structured protocol messages and updates the blackboard.

This is called by the conductor's event processing loop to handle
structured JSON messages from agents. It parses messages once and
updates the blackboard with progress, error, and completion data.

Usage:
    python3 protocol-handler.py <event_json_string>
    echo '{"v":1,"t":"status","a":"gemini","track":"my-track","pct":45}' | python3 protocol-handler.py
    python3 protocol-handler.py --batch <event_json_array>

The handler updates blackboard keys:
    - agent_progress_<name>: Latest progress data for dashboard
    - agent_protocol_<name>: Raw protocol message
    - fleet_health_<name>: Error state if error message
    - protocol_errors: Error queue for active errors
    - track_completed_by_<slug>: Track completion marker
"""

import json
import os
import sys
import time
from pathlib import Path


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
UTILS_FILE = SCRIPT_DIR / "utils.sh"


# ============================================================
# Blackboard Interface
# ============================================================

def get_blackboard_db():
    """Get blackboard database path from environment or default."""
    db_path = os.environ.get("BLACKBOARD_DB_PATH")
    if db_path and os.path.exists(db_path):
        return db_path

    # Try to find from project root
    candidate = PROJECT_ROOT / ".ai-colab" / "blackboard.db"
    if candidate.exists():
        return str(candidate)

    # Try hcom database
    candidate = PROJECT_ROOT / ".hcom" / "hcom.db"
    if candidate.exists():
        return str(candidate)

    return None


def blackboard_set(key: str, value: str) -> bool:
    """Set a value in the blackboard."""
    import sqlite3
    import time

    db_path = get_blackboard_db()
    if not db_path:
        return False

    try:
        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA busy_timeout=5000")
        conn.execute(
            "INSERT OR REPLACE INTO kv (key, value, expires_at) VALUES (?, ?, 0)",
            (key, value)
        )
        conn.commit()
        conn.close()
        return True
    except Exception:
        return False


def blackboard_get(key: str) -> str:
    """Get a value from the blackboard."""
    import sqlite3

    db_path = get_blackboard_db()
    if not db_path:
        return ""

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.execute("SELECT value FROM kv WHERE key = ? AND (expires_at = 0 OR expires_at > ?)",
                            (key, int(time.time())))
        row = cursor.fetchone()
        conn.close()
        return row[0] if row else ""
    except Exception:
        return ""


# ============================================================
# Protocol Handler
# ============================================================

def is_protocol_message(text: str) -> bool:
    """Check if message text is a structured protocol message."""
    if not text or not isinstance(text, str):
        return False
    return text.strip().startswith("{")


def parse_protocol_message(text: str) -> dict:
    """Parse a structured protocol message.

    Returns:
        Parsed message dict with validated fields, or empty dict if invalid.
    """
    try:
        msg = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return {}

    # Validate protocol version
    if msg.get("v") != 1:
        return {}

    # Validate message type
    msg_type = msg.get("t", "")
    valid_types = {"status", "heartbeat", "request", "response", "error", "complete"}
    if msg_type not in valid_types:
        return {}

    return msg


def handle_status_message(msg: dict) -> list:
    """Handle a status protocol message.

    Returns:
        List of blackboard updates to apply.
    """
    agent = msg.get("a", "")
    if not agent:
        return []

    updates = []
    ts = int(time.time())

    # Store raw protocol message
    updates.append((f"agent_protocol_{agent}", json.dumps(msg)))

    # Store structured progress data
    progress_data = {
        "agent": agent,
        "track": msg.get("track", ""),
        "pct": msg.get("pct", 0),
        "step": msg.get("step", ""),
        "phase": msg.get("phase", ""),
        "eta": msg.get("eta", 0),
        "ts": ts
    }
    updates.append((f"agent_progress_{agent}", json.dumps(progress_data)))

    # Log for conductor
    track = msg.get("track", "")
    pct = msg.get("pct", 0)
    step = msg.get("step", "")
    print(f"STATUS: Agent {agent}: {pct}% on {track} — {step}", file=sys.stderr)

    return updates


def handle_error_message(msg: dict) -> list:
    """Handle an error protocol message.

    Returns:
        List of blackboard updates to apply.
    """
    agent = msg.get("a", "")
    if not agent:
        return []

    updates = []
    ts = int(time.time())

    # Store raw protocol message
    updates.append((f"agent_protocol_{agent}", json.dumps(msg)))

    # Append to error queue
    existing_errors = blackboard_get("protocol_errors")
    if existing_errors:
        updates.append(("protocol_errors", existing_errors + "|||" + json.dumps(msg)))
    else:
        updates.append(("protocol_errors", json.dumps(msg)))

    # Update agent health to reflect error state
    err_health = {
        "status": "error",
        "err": msg.get("err", "unknown"),
        "detail": msg.get("detail", ""),
        "ts": ts
    }
    updates.append((f"fleet_health_{agent}", json.dumps(err_health)))

    # Log for conductor
    track = msg.get("track", "")
    err = msg.get("err", "")
    detail = msg.get("detail", "")
    print(f"ERROR: Agent {agent}: {err} on {track} — {detail}", file=sys.stderr)

    return updates


def handle_complete_message(msg: dict) -> list:
    """Handle a completion protocol message.

    Returns:
        List of blackboard updates to apply.
    """
    agent = msg.get("a", "")
    track = msg.get("track", "")
    if not agent or not track:
        return []

    updates = []

    # Store raw protocol message
    updates.append((f"agent_protocol_{agent}", json.dumps(msg)))

    # Mark track as potentially complete
    track_slug = track.lower().replace(" ", "-")
    import re
    track_slug = re.sub(r"[^a-z0-9-]+", "-", track_slug).strip("-")
    if track_slug:
        updates.append((f"track_completed_by_{track_slug}", agent))

    # Log for conductor
    detail = msg.get("detail", "")
    print(f"COMPLETE: Agent {agent}: {track} — {detail}", file=sys.stderr)

    return updates


def handle_heartbeat_message(msg: dict) -> list:
    """Handle a heartbeat protocol message.

    Returns:
        List of blackboard updates to apply.
    """
    agent = msg.get("a", "")
    if not agent:
        return []

    ts = int(time.time())
    return [(f"agent_heartbeat_{agent}", str(ts))]


def handle_request_response_message(msg: dict) -> list:
    """Handle request/response protocol messages.

    Returns:
        List of blackboard updates to apply.
    """
    agent = msg.get("a", "")
    if not agent:
        return []

    return [(f"agent_protocol_{agent}", json.dumps(msg))]


def process_protocol_message(text: str) -> bool:
    """Process a structured protocol message and update the blackboard.

    Args:
        text: JSON string of the protocol message

    Returns:
        True if message was processed, False otherwise.
    """
    if not is_protocol_message(text):
        return False

    msg = parse_protocol_message(text)
    if not msg:
        return False

    msg_type = msg.get("t", "")

    # Dispatch to appropriate handler
    handlers = {
        "status": handle_status_message,
        "error": handle_error_message,
        "complete": handle_complete_message,
        "heartbeat": handle_heartbeat_message,
        "request": handle_request_response_message,
        "response": handle_request_response_message,
    }

    handler = handlers.get(msg_type)
    if not handler:
        return False

    updates = handler(msg)

    # Apply all blackboard updates
    for key, value in updates:
        blackboard_set(key, value)

    return True


def process_events_batch(events: list) -> int:
    """Process a batch of events and return count of protocol messages processed."""
    processed = 0

    for event in events:
        # Extract msg_text from event
        if isinstance(event, str):
            text = event
        elif isinstance(event, dict):
            text = event.get("msg_text", "")
        else:
            continue

        if process_protocol_message(text):
            processed += 1

    return processed


# ============================================================
# CLI Interface
# ============================================================

def main():
    if len(sys.argv) < 2:
        # Read from stdin
        if not sys.stdin.isatty():
            try:
                data = sys.stdin.read().strip()
                if process_protocol_message(data):
                    print("Processed protocol message")
                else:
                    print("Not a protocol message")
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
        else:
            print("Usage: python3 protocol-handler.py <event_json>")
            print("       echo '{\"v\":1,\"t\":\"status\"...}' | python3 protocol-handler.py")
            sys.exit(1)
    else:
        command = sys.argv[1]

        if command == "--batch" and len(sys.argv) > 2:
            # Process batch of events
            try:
                events = json.loads(sys.argv[2])
                count = process_events_batch(events)
                print(f"Processed {count} protocol messages")
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
        else:
            # Process single message from argument
            message = sys.argv[1]
            if process_protocol_message(message):
                print("Processed protocol message")
            else:
                print("Not a protocol message")


if __name__ == "__main__":
    main()
