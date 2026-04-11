#!/usr/bin/env python3
"""
Enhanced User Console for ai-colab Dashboard (P17.3)
Readline-based command interface with history, tab completion, and help.

Usage: python3 console.py --name <user_name>
"""

import cmd
import os
import sys
import readline
import subprocess
import json
from pathlib import Path

# History file location
HISTFILE = os.path.expanduser("~/.ai-colab-console-history")
HISTFILE_SIZE = 1000

# Command definitions
CONDUCTOR_COMMANDS = {
    "!status": "Get project health & progress",
    "!test": "Run all automated tests",
    "!build": "Build project and integrated apps",
    "!help": "Show all available commands",
    "!kb <query>": "Search architectural knowledge base",
    "!git-sync": "Pull latest changes from remote",
    "!approve <slug>": "Approve a track for merge",
    "!evolve": "Propose new track autonomously",
    "!web-start": "Start Web UI dashboard",
    "!web-stop": "Stop Web UI dashboard",
}

# Command aliases (shortcuts)
COMMAND_ALIASES = {
    "s": "!status",
    "t": "!test",
    "b": "!build",
    "h": "!help",
}


class UserConsole(cmd.Cmd):
    """Enhanced readline-based console for ai-colab."""

    intro = "Welcome to the ai-colab User Console. Type !help or ? to list commands."
    prompt = "> "

    def __init__(self, user_name="user"):
        super().__init__()
        self.user_name = user_name
        self.hcom_name = os.environ.get("HCOM_NAME", user_name)

        # Load history
        self._load_history()

    def _load_history(self):
        """Load command history from file."""
        try:
            readline.read_history_file(HISTFILE)
            readline.set_history_length(HISTFILE_SIZE)
        except FileNotFoundError:
            pass

    def _save_history(self):
        """Save command history to file."""
        try:
            readline.write_history_file(HISTFILE)
        except Exception:
            pass

    def _send_command(self, command):
        """Send command to conductor via hcom."""
        try:
            cmd = [
                "hcom", "send",
                "--name", self.hcom_name,
                "@conductor",
                "--", command
            ]
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.stdout:
                print(result.stdout)
            if result.returncode != 0 and result.stderr:
                print(f"Error: {result.stderr}")
        except subprocess.TimeoutExpired:
            print("Error: Command timed out")
        except FileNotFoundError:
            print("Error: hcom not found. Please run ./install.sh")
        except Exception as e:
            print(f"Error: {e}")

    def _resolve_alias(self, text):
        """Resolve command aliases."""
        text = text.strip()
        for alias, full_cmd in COMMAND_ALIASES.items():
            if text == alias or text.startswith(alias + " "):
                if text == alias:
                    return full_cmd
                else:
                    # Pass through any arguments
                    args = text[len(alias):].strip()
                    return f"{full_cmd} {args}"
        return text

    # ---- Command handlers ----

    def do_EOF(self, arg):
        """Exit the console."""
        print("\nGoodbye!")
        self._save_history()
        return True

    def do_quit(self, arg):
        """Exit the console. Usage: quit"""
        print("Goodbye!")
        self._save_history()
        return True

    def do_exit(self, arg):
        """Exit the console. Usage: exit"""
        return self.do_quit(arg)

    def do_help(self, arg):
        """Show help for commands. Usage: help [command]"""
        if arg:
            # Show help for specific command
            if arg in CONDUCTOR_COMMANDS:
                print(f"\n{arg}: {CONDUCTOR_COMMANDS[arg]}")
            elif arg.startswith("!"):
                print(f"\n{arg}: Conductor command (sent via hcom)")
            else:
                print(f"\nNo help available for '{arg}'")
        else:
            # Show all commands
            print("\n" + "=" * 60)
            print("  ai-colab User Console Commands")
            print("=" * 60)
            print("\nConductor Commands:")
            for cmd, desc in CONDUCTOR_COMMANDS.items():
                print(f"  {cmd:<20} - {desc}")
            print("\nAliases:")
            for alias, full_cmd in COMMAND_ALIASES.items():
                print(f"  {alias:<20} - {full_cmd}")
            print("\nConsole Commands:")
            print("  quit/exit            - Exit the console")
            print("  help [command]       - Show help for a command")
            print("  history              - Show command history")
            print("\nNavigation:")
            print("  Up/Down arrows       - Browse command history")
            print("  Tab                  - Auto-complete commands")
            print("=" * 60)

    def do_history(self, arg):
        """Show command history. Usage: history"""
        history = []
        for i in range(readline.get_current_history_length()):
            history.append(readline.get_history_item(i + 1))
        if history:
            print("\nCommand History:")
            for i, cmd in enumerate(history[-20:], 1):  # Show last 20
                print(f"  {i:>3}. {cmd}")
        else:
            print("\nNo command history yet.")

    def default(self, line):
        """Handle unrecognized commands by sending to conductor."""
        line = line.strip()
        if not line:
            return

        # Resolve aliases
        line = self._resolve_alias(line)

        # Check if it's a conductor command
        if line.startswith("!"):
            self._send_command(line)
        else:
            print(f"Unknown command: {line}")
            print("Type !help to see available commands.")

    def completedefault(self, text, line, begidx, endidx):
        """Tab completion for commands."""
        # Get all possible completions
        completions = list(CONDUCTOR_COMMANDS.keys()) + list(COMMAND_ALIASES.keys())

        # Filter based on current input
        if text:
            completions = [c for c in completions if c.startswith(text)]

        return completions

    def preloop(self):
        """Print welcome message."""
        print(f"\nLogged in as: {self.user_name}")
        print(f"HCOM Name: {self.hcom_name}")
        print("\nType !help to see available commands.")
        print("Press Ctrl+D or type 'quit' to exit.\n")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="ai-colab User Console")
    parser.add_argument("--name", default="user", help="User name")
    args = parser.parse_args()

    try:
        console = UserConsole(user_name=args.name)
        console.cmdloop()
    except KeyboardInterrupt:
        print("\nGoodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
