# Global Conductor Agent

Universal project management agent with hcom integration. Works with any project.

## Quick Start

```bash
# Launch conductor (auto-detects project)
conductor

# Launch with specific project
conductor -p /path/to/project

# Use Qwen instead of Gemini
conductor qwen

# Check status
conductor-status
```

## Installation

```bash
./scripts/conductor/install.sh
```

This will:
- Create symlinks in `~/.local/bin/`
- Add aliases and environment variables to your shell configuration (`.zshrc`, `.bashrc`, or `.bash_profile`)
- Make commands available globally

> **Note for Zsh users:** To avoid shell incompatibility issues (e.g., Oh My Zsh), the installer does not automatically source `.zshrc`. You should run `source ~/.zshrc` after the installation completes.

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `conductor` | Launch with auto-detected project |
| `conductor -p <dir>` | Launch with specific project |
| `conductor qwen` | Use Qwen instead of Gemini |
| `conductor -n <name>` | Custom agent name |
| `conductor-status` | Check status |

### Examples

```bash
# Auto-detect project from current directory
conductor

# Specify project
conductor -p ~/projects/my-app

# Custom agent name
conductor -n my-project-conductor

# Use Qwen
conductor qwen

# Custom hcom thread
conductor -t my-thread
```

## Project Detection

The conductor automatically detects projects by searching for:
- `conductor/tracks.md` OR
- `conductor/product.md`

Starting from the current directory and searching parent directories.

## HCOM Integration

### Automatic
- Registers with hcom on launch
- Subscribes to `plan-sync` thread
- Broadcasts status updates

### Manual Commands

```bash
# Send message
hcom send @conductor_gemini -- Status update?

# View events
hcom events | tail -20

# View transcript
hcom transcript conductor_gemini
```

## Architecture

```
~/.hcom/scripts/conductor/     ← Global utilities
├── launch.sh                   ← Main launcher
├── status.sh                   ← Status monitor
├── conductor-agent.md          ← Agent template
├── install.sh                  ← Installer
└── README.md                   ← This file

<project>/.qwen/conductor/     ← Project-specific (optional)
├── conductor-agent.md          ← Custom agent personality
└── project-context.md          ← Project-specific context
```

## Configuration

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `HCOM_AGENT_NAME` | Agent name | `conductor_<model>` |
| `HCOM_PROJECT_DIR` | Project directory | Auto-detected |
| `HCOM_THREAD_NAME` | hcom thread | `plan-sync` |

### Project-Specific Override

Create `<project>/.qwen/conductor-agent.md` to override the global agent template with project-specific personality and context.

## Multi-Project Usage

```bash
# Project 1
cd ~/projects/project-a
conductor

# Project 2 (in new terminal)
cd ~/projects/project-b
conductor -n conductor-b

# Both run simultaneously with different names
```

## Troubleshooting

**No project found:**
```bash
# Specify project explicitly
conductor -p /path/to/project

# Verify project structure
ls -la /path/to/project/conductor/
```

**Agent not appearing in hcom:**
```bash
hcom status
hcom list -v
```

**Command not found:**
```bash
# Ensure ~/.local/bin is in PATH
echo $PATH | grep local

# Or use full path
~/.hcom/scripts/conductor/launch.sh
```

## Files

| File | Purpose |
|------|---------|
| `launch.sh` | Universal launcher with project detection |
| `status.sh` | Status monitor with auto-detection |
| `conductor-agent.md` | Generic agent template |
| `install.sh` | Installation script |

## License

Part of hcom utilities. Available for all projects.
