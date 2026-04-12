#!/usr/bin/env python3
"""
ai-colab Agent Memory Manager (P5.2)
Manages persistent conversation history for LLM CLI agents.

Features:
- Store/retrieve conversation messages per agent
- Configurable context window (max messages or max bytes)
- Memory compression via summarization
- Automatic cleanup of old messages

Usage:
    python3 memory-manager.py save --agent gemini --role user --message "Hello"
    python3 memory-manager.py load --agent gemini --max-messages 50
    python3 memory-manager.py compress --agent gemini
    python3 memory-manager.py status --agent gemini
    python3 memory-manager.py clear --agent gemini
"""

import argparse
import json
import os
import sqlite3
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
MEMORY_DIR = PROJECT_ROOT / ".ai-colab" / "memory"
MEMORY_DB = MEMORY_DIR / "agent-memory.db"

# Default configuration
DEFAULT_CONFIG = {
    "max_messages": 200,
    "max_bytes": 50000,
    "compression_threshold": 150,
    "compression_target": 50,
    "save_interval_seconds": 60,
    "context_priority": ["system", "assistant", "user"],
}


class AgentMemoryManager:
    """Manages persistent conversation history for an agent."""

    def __init__(self, agent: str, config: Optional[Dict[str, Any]] = None):
        self.agent = agent
        self.config = {**DEFAULT_CONFIG, **(config or {})}
        self._ensure_db()

    def _ensure_db(self):
        """Create database and tables if they don't exist."""
        MEMORY_DIR.mkdir(parents=True, exist_ok=True)

        self.conn = sqlite3.connect(str(MEMORY_DB))
        self.conn.row_factory = sqlite3.Row
        cursor = self.conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp REAL NOT NULL,
                is_summary INTEGER DEFAULT 0,
                metadata TEXT DEFAULT '{}'
            )
        """)

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_messages_agent
            ON messages(agent, timestamp)
        """)

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS summaries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent TEXT NOT NULL,
                start_message_id INTEGER NOT NULL,
                end_message_id INTEGER NOT NULL,
                summary TEXT NOT NULL,
                created_at REAL NOT NULL,
                message_count INTEGER NOT NULL
            )
        """)

        self.conn.commit()

    def save_message(self, role: str, content: str, metadata: Optional[Dict] = None):
        """Save a conversation message."""
        cursor = self.conn.cursor()
        cursor.execute(
            """
            INSERT INTO messages (agent, role, content, timestamp, is_summary, metadata)
            VALUES (?, ?, ?, ?, 0, ?)
            """,
            (
                self.agent,
                role,
                content,
                time.time(),
                json.dumps(metadata or {}),
            ),
        )
        self.conn.commit()

        # Check if compression is needed
        message_count = self.get_message_count()
        if message_count >= self.config["compression_threshold"]:
            self.compress()

    def save_messages(self, messages: List[Dict[str, str]]):
        """Save multiple messages at once."""
        cursor = self.conn.cursor()
        for msg in messages:
            cursor.execute(
                """
                INSERT INTO messages (agent, role, content, timestamp, is_summary, metadata)
                VALUES (?, ?, ?, ?, 0, ?)
                """,
                (
                    self.agent,
                    msg.get("role", "user"),
                    msg.get("content", ""),
                    time.time(),
                    json.dumps(msg.get("metadata", {})),
                ),
            )
        self.conn.commit()

    def load_context(self, max_messages: Optional[int] = None, max_bytes: Optional[int] = None) -> List[Dict[str, str]]:
        """Load conversation context for agent prompt injection."""
        max_msgs = max_messages or self.config["max_messages"]
        max_b = max_bytes or self.config["max_bytes"]

        cursor = self.conn.cursor()

        # Load summaries first
        cursor.execute(
            """
            SELECT summary, start_message_id, end_message_id, message_count
            FROM summaries
            WHERE agent = ?
            ORDER BY created_at DESC
            LIMIT 5
            """,
            (self.agent,),
        )
        summaries = cursor.fetchall()

        # Load recent messages
        cursor.execute(
            """
            SELECT role, content, timestamp, is_summary, metadata
            FROM messages
            WHERE agent = ?
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            (self.agent, max_msgs),
        )
        messages = cursor.fetchall()

        # Build context
        context = []

        # Add summaries (oldest first)
        for summary in reversed(summaries):
            context.append({
                "role": "system",
                "content": f"[Previous conversation summary]: {summary['summary']}",
                "is_summary": True,
            })

        # Add recent messages (oldest first)
        total_bytes = 0
        for msg in reversed(messages):
            msg_dict = {
                "role": msg["role"],
                "content": msg["content"],
                "is_summary": bool(msg["is_summary"]),
            }
            msg_bytes = len(json.dumps(msg_dict).encode("utf-8"))

            if total_bytes + msg_bytes > max_b:
                break

            context.append(msg_dict)
            total_bytes += msg_bytes

        return context

    def compress(self):
        """Compress old messages into summaries."""
        cursor = self.conn.cursor()

        # Get message count
        cursor.execute(
            "SELECT COUNT(*) FROM messages WHERE agent = ? AND is_summary = 0",
            (self.agent,),
        )
        message_count = cursor.fetchone()[0]

        if message_count < self.config["compression_threshold"]:
            return 0

        # Get oldest messages to compress
        messages_to_compress = message_count - self.config["compression_target"]

        cursor.execute(
            """
            SELECT id, role, content
            FROM messages
            WHERE agent = ? AND is_summary = 0
            ORDER BY timestamp ASC
            LIMIT ?
            """,
            (self.agent, messages_to_compress),
        )
        messages = cursor.fetchall()

        if not messages:
            return 0

        # Create summary (simple concatenation for now; could use LLM)
        summary_content = "\n".join(
            f"{msg['role']}: {msg['content'][:100]}" for msg in messages[:20]
        )
        summary = f"Conversation summary ({messages_to_compress} messages): {summary_content}"

        # Save summary
        start_id = messages[0]["id"]
        end_id = messages[-1]["id"]

        cursor.execute(
            """
            INSERT INTO summaries (agent, start_message_id, end_message_id, summary, created_at, message_count)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (self.agent, start_id, end_id, summary, time.time(), len(messages)),
        )

        # Delete compressed messages
        cursor.execute(
            """
            DELETE FROM messages
            WHERE agent = ? AND id BETWEEN ? AND ? AND is_summary = 0
            """,
            (self.agent, start_id, end_id),
        )

        self.conn.commit()
        return len(messages)

    def get_message_count(self) -> int:
        """Get total message count for agent."""
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT COUNT(*) FROM messages WHERE agent = ? AND is_summary = 0",
            (self.agent,),
        )
        return cursor.fetchone()[0]

    def get_storage_size(self) -> int:
        """Get storage size in bytes for agent."""
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT SUM(length(content)) FROM messages WHERE agent = ?",
            (self.agent,),
        )
        return cursor.fetchone()[0] or 0

    def get_status(self) -> Dict[str, Any]:
        """Get memory status for agent."""
        return {
            "agent": self.agent,
            "message_count": self.get_message_count(),
            "storage_bytes": self.get_storage_size(),
            "config": {
                "max_messages": self.config["max_messages"],
                "max_bytes": self.config["max_bytes"],
                "compression_threshold": self.config["compression_threshold"],
            },
        }

    def clear(self):
        """Clear all messages and summaries for agent."""
        cursor = self.conn.cursor()
        cursor.execute("DELETE FROM messages WHERE agent = ?", (self.agent,))
        cursor.execute("DELETE FROM summaries WHERE agent = ?", (self.agent,))
        self.conn.commit()

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()


def main():
    parser = argparse.ArgumentParser(description="ai-colab Agent Memory Manager")
    parser.add_argument(
        "command",
        choices=["save", "load", "compress", "status", "clear", "export"],
        help="Command to execute",
    )
    parser.add_argument("--agent", required=True, help="Agent name")
    parser.add_argument("--role", help="Message role (user/assistant/system)")
    parser.add_argument("--message", help="Message content")
    parser.add_argument("--max-messages", type=int, help="Max messages to load")
    parser.add_argument("--max-bytes", type=int, help="Max bytes to load")
    parser.add_argument("--file", help="File to save/load messages from")
    parser.add_argument("--config", help="Config file path")

    args = parser.parse_args()

    # Load config if provided
    config = {}
    if args.config and os.path.exists(args.config):
        with open(args.config) as f:
            config = json.load(f)

    manager = AgentMemoryManager(args.agent, config)

    try:
        if args.command == "save":
            if not args.role or not args.message:
                print("Error: --role and --message required for save")
                sys.exit(1)

            manager.save_message(args.role, args.message)
            print(f"Saved message for {args.agent} ({args.role})")

        elif args.command == "load":
            context = manager.load_context(
                max_messages=args.max_messages,
                max_bytes=args.max_bytes,
            )

            if args.file:
                with open(args.file, "w") as f:
                    json.dump(context, f, indent=2)
                print(f"Loaded {len(context)} messages to {args.file}")
            else:
                print(json.dumps(context, indent=2))

        elif args.command == "compress":
            compressed = manager.compress()
            print(f"Compressed {compressed} messages for {args.agent}")

        elif args.command == "status":
            status = manager.get_status()
            print(json.dumps(status, indent=2))

        elif args.command == "clear":
            manager.clear()
            print(f"Cleared memory for {args.agent}")

        elif args.command == "export":
            context = manager.load_context()
            output_file = args.file or f"memory_{args.agent}_{int(time.time())}.json"
            with open(output_file, "w") as f:
                json.dump(context, f, indent=2)
            print(f"Exported {len(context)} messages to {output_file}")

    finally:
        manager.close()


if __name__ == "__main__":
    main()
