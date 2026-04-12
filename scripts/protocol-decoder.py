#!/usr/bin/env python3
"""
ai-colab Protocol Decoder (P6.1)
Parses structured protocol messages and generates human-readable summaries.
Used by the conductor and dashboard to process agent communications.

Usage:
    echo '{"v":1,"t":"status","a":"gemini","track":"implement-api","pct":45,"step":"coding"}' | python3 protocol-decoder.py
    python3 protocol-decoder.py --file message.json
    python3 protocol-decoder.py --summary '{"v":1,"t":"status","a":"gemini","track":"implement-api","pct":45,"step":"coding"}'
    python3 protocol-decoder.py --validate '{"v":1,"t":"status","a":"gemini"}'
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, Optional


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
PROTOCOL_FILE = PROJECT_ROOT / "config" / "message-protocol.json"

# Load protocol schema
PROTOCOL_SCHEMA = {}
if PROTOCOL_FILE.exists():
    with open(PROTOCOL_FILE) as f:
        PROTOCOL_SCHEMA = json.load(f)

# Field definitions from schema
FIELD_DEFS = PROTOCOL_SCHEMA.get("fields", {})
MESSAGE_TYPES = PROTOCOL_SCHEMA.get("message_types", {})


# ============================================================
# Validation
# ============================================================

def validate_message(message: Dict[str, Any]) -> tuple[bool, str]:
    """Validate a protocol message against the schema.

    Returns:
        (is_valid, error_message)
    """
    # Check protocol version
    version = message.get("v", 0)
    if version != PROTOCOL_SCHEMA.get("protocol", {}).get("version", 1):
        return False, f"Unsupported protocol version: {version}"

    # Check message type
    msg_type = message.get("t", "")
    if msg_type not in MESSAGE_TYPES:
        return False, f"Unknown message type: {msg_type}"

    # Check required fields
    type_config = MESSAGE_TYPES.get(msg_type, {})
    required = type_config.get("required_fields", [])

    for field in required:
        if field not in message:
            return False, f"Missing required field: {field}"

    # Validate field types and constraints
    for field_name, value in message.items():
        field_def = FIELD_DEFS.get(field_name, {})

        # Type validation
        expected_type = field_def.get("type", "")
        if expected_type == "integer" and not isinstance(value, int):
            return False, f"Field '{field_name}' must be integer, got {type(value).__name__}"
        elif expected_type == "string" and not isinstance(value, str):
            return False, f"Field '{field_name}' must be string, got {type(value).__name__}"
        elif expected_type == "boolean" and not isinstance(value, bool):
            return False, f"Field '{field_name}' must be boolean, got {type(value).__name__}"
        elif expected_type == "array" and not isinstance(value, list):
            return False, f"Field '{field_name}' must be array, got {type(value).__name__}"

        # Enum validation
        if "enum" in field_def and value not in field_def["enum"]:
            return False, f"Field '{field_name}' must be one of {field_def['enum']}, got '{value}'"

        # Range validation
        if "min" in field_def and isinstance(value, (int, float)):
            if value < field_def["min"]:
                return False, f"Field '{field_name}' must be >= {field_def['min']}, got {value}"
        if "max" in field_def and isinstance(value, (int, float)):
            if value > field_def["max"]:
                return False, f"Field '{field_name}' must be <= {field_def['max']}, got {value}"

        # Length validation
        if "max_length" in field_def and isinstance(value, str):
            if len(value) > field_def["max_length"]:
                return False, f"Field '{field_name}' exceeds max length ({field_def['max_length']})"

    return True, "valid"


# ============================================================
# Human-Readable Summary Generation
# ============================================================

def generate_summary(message: Dict[str, Any]) -> str:
    """Generate a human-readable summary from a structured message.

    Examples:
        {"t":"status","a":"gemini","track":"implement-api","pct":45,"step":"coding","eta":1800}
        → "Gemini: 45% complete on implement-api — coding (~30 min remaining)"

        {"t":"error","a":"qwen","track":"fix-bug","err":"test_failed","detail":"3 tests failing"}
        → "⚠ Qwen encountered test_failed on fix-bug: 3 tests failing"

        {"t":"complete","a":"claude","track":"write-docs","detail":"All sections complete"}
        → "✅ Claude completed write-docs: All sections complete"
    """
    msg_type = message.get("t", "unknown")
    agent = message.get("a", "unknown")
    agent_display = agent.replace("_", " ").title()

    if msg_type == "status":
        track = message.get("track", "unknown")
        pct = message.get("pct", 0)
        step = message.get("step", "")
        eta = message.get("eta", 0)

        summary = f"{agent_display}: {pct}% complete on {track}"
        if step:
            summary += f" — {step}"
        if eta > 0:
            minutes = eta // 60
            if minutes > 0:
                summary += f" (~{minutes} min remaining)"
            else:
                summary += f" (~{eta}s remaining)"

        blockers = message.get("blockers", [])
        if blockers:
            summary += f" ⚠️  Blockers: {', '.join(blockers)}"

        return summary

    elif msg_type == "heartbeat":
        latency = message.get("latency_ms", 0)
        load = message.get("load", 0)
        summary = f"💓 {agent_display} alive"
        if latency > 0:
            summary += f" ({latency}ms latency)"
        if load > 0:
            summary += f" (load: {load:.0%})"
        return summary

    elif msg_type == "request":
        track = message.get("track", "unknown")
        detail = message.get("detail", "")
        target = message.get("target_agent", "")
        priority = message.get("priority", "normal")

        summary = f"📤 {agent_display} requests"
        if target:
            summary += f" {target.replace('_', ' ').title()}"
        summary += f" for {track}"
        if detail:
            summary += f": {detail}"
        if priority != "normal":
            summary += f" [{priority.upper()}]"
        return summary

    elif msg_type == "response":
        track = message.get("track", "unknown")
        status = message.get("status", "unknown")
        detail = message.get("detail", "")

        summary = f"📨 {agent_display} responded: {status}"
        if detail:
            summary += f" — {detail}"
        return summary

    elif msg_type == "error":
        track = message.get("track", "unknown")
        err = message.get("err", "unknown_error")
        detail = message.get("detail", "")
        recoverable = message.get("recoverable", True)
        retry = message.get("retry_count", 0)

        summary = f"⚠ {agent_display} encountered {err} on {track}"
        if detail:
            summary += f": {detail}"
        if retry > 0:
            summary += f" (retry #{retry})"
        if not recoverable:
            summary += " [NOT RECOVERABLE]"
        return summary

    elif msg_type == "complete":
        track = message.get("track", "unknown")
        detail = message.get("detail", "")
        artifacts = message.get("artifacts", [])

        summary = f"✅ {agent_display} completed {track}"
        if detail:
            summary += f": {detail}"
        if artifacts:
            summary += f" ({len(artifacts)} files)"
        return summary

    else:
        return f"[{msg_type}] {agent_display}: {json.dumps(message)}"


def generate_tmux_status_line(messages: list[Dict[str, Any]]) -> str:
    """Generate a tmux status line from multiple agent messages.

    Format: [✓ gemini] [⏳ qwen: coding] [✗ claude: error] [? unknown]
    """
    parts = []

    for msg in messages:
        agent = msg.get("a", "unknown")
        msg_type = msg.get("t", "")

        if msg_type == "status":
            pct = msg.get("pct", 0)
            phase = msg.get("phase", "")

            if pct >= 100:
                icon = "✓"
            elif phase in ("coding", "analyzing", "planning"):
                icon = "⏳"
            else:
                icon = "✓"

            detail = f": {phase}" if phase else ""
            parts.append(f"[{icon} {agent}{detail}]")

        elif msg_type == "error":
            parts.append(f"[✗ {agent}: error]")

        elif msg_type == "heartbeat":
            parts.append(f"[✓ {agent}]")

        else:
            parts.append(f"[? {agent}]")

    return " ".join(parts)


# ============================================================
# CLI Interface
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="ai-colab Protocol Decoder")
    parser.add_argument("command", nargs="?", choices=["decode", "summary", "validate", "status-line", "help"],
                        default="decode", help="Command to execute")
    parser.add_argument("--file", "-f", help="Read message from JSON file")
    parser.add_argument("--summary", "-s", help="Generate summary from JSON string")
    parser.add_argument("--validate", "-v", help="Validate JSON message")
    parser.add_argument("--status-line", "-l", help="Generate tmux status line from JSON array")
    parser.add_argument("--pretty", "-p", action="store_true", help="Pretty print output")

    args = parser.parse_args()

    # Read message from file or stdin
    message = None

    if args.file:
        with open(args.file) as f:
            message = json.load(f)
    elif args.summary:
        message = json.loads(args.summary)
    elif args.validate:
        message = json.loads(args.validate)
    elif args.status_line:
        messages = json.loads(args.status_line)
        line = generate_tmux_status_line(messages)
        print(line)
        return
    elif not sys.stdin.isatty():
        message = json.load(sys.stdin)
    else:
        parser.print_help()
        return

    if args.validate or args.command == "validate":
        is_valid, error_msg = validate_message(message)
        if is_valid:
            print(f"✅ Valid: {json.dumps(message, indent=2 if args.pretty else None)}")
        else:
            print(f"❌ Invalid: {error_msg}")
            sys.exit(1)

    elif args.summary or args.command == "summary":
        summary = generate_summary(message)
        print(summary)

    elif args.command == "status-line":
        # For stdin array input
        if not sys.stdin.isatty():
            messages = json.load(sys.stdin)
            line = generate_tmux_status_line(messages)
            print(line)
        else:
            print("Provide JSON array via stdin or --status-line flag")

    else:  # decode
        print(json.dumps(message, indent=2 if args.pretty else None))
        print()
        print("Summary:", generate_summary(message))


if __name__ == "__main__":
    main()
