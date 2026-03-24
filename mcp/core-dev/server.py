#!/usr/bin/env python3
import os
import json
import sqlite3
import subprocess
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Core Dev")

# Constants
DB_PATH = os.path.expanduser("~/.hcom/hcom.db")
TRACKS_FILE = "conductor/tracks.md"

@mcp.tool()
def get_project_status() -> str:
    """Returns a structured summary of the current project state from the Blackboard."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT key, value FROM kv")
        kv = dict(cursor.fetchall())
        conn.close()
        return json.dumps(kv, indent=2)
    except Exception as e:
        return f"Error: {str(e)}"

@mcp.tool()
def request_task_handoff(target_agent: str, task_context: str) -> str:
    """Sends a formalized handoff request to another agent via hcom."""
    try:
        cmd = ["hcom", "send", f"@{target_agent}", "--intent", "request", "--thread", "task-handoff", "--", task_context]
        subprocess.run(cmd, check=True)
        return f"Successfully sent handoff request to @{target_agent}."
    except Exception as e:
        return f"Error sending handoff: {str(e)}"

@mcp.tool()
def propose_track(title: str, description: str, dependencies: str = "") -> str:
    """Proposes a new development track to be added to conductor/tracks.md."""
    try:
        # Just return the markdown formatted string so the agent can write it or we can automate it
        track_entry = f"- [ ] **Track: {title}**\n  - **Assigned:** @pending\n  - **Description:** {description}\n"
        if dependencies:
            track_entry += f"  - **Dependencies:** {dependencies}\n"
        
        # Optionally append to file automatically
        if os.path.isfile(TRACKS_FILE):
            with open(TRACKS_FILE, "a") as f:
                f.write(f"\n{track_entry}")
            return f"Proposed track '{title}' has been appended to {TRACKS_FILE}."
        return f"Tracks file not found. Here is the entry:\n{track_entry}"
    except Exception as e:
        return f"Error proposing track: {str(e)}"

@mcp.tool()
def verify_style(file_path: str) -> str:
    """Triggers the automated code reviewer for a specific file."""
    try:
        # Assuming hcom-code-review.sh is in the path or scripts dir
        scripts_dir = os.path.expanduser("~/.hcom/scripts")
        cmd = ["bash", os.path.join(scripts_dir, "hcom-code-review.sh"), file_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout
    except Exception as e:
        return f"Error running style check: {str(e)}"

if __name__ == "__main__":
    mcp.run()
