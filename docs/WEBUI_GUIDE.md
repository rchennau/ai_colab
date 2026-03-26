# Web UI Guide

The ai-colab Web UI provides a powerful browser-based interface for managing your multi-agent environment.

## Getting Started

1.  **Launch the Web UI:**
    Run the following command in the project root:
    ```bash
    docker-compose up -d
    ```

2.  **Access the interface:**
    Navigate to `http://localhost:8080`.

## Features

### 1. Setup Wizard
The first time you access the Web UI, you'll be guided through a setup wizard to:
-   Enable LLM agents (Gemini, Qwen, DeepSeek, etc.).
-   Configure compute backends (NVIDIA NIM, RunPod, Local).
-   Register modular addons (Atari-8bit).

### 2. Dashboard
The main dashboard provides a real-time overview of your environment:
-   **System Status:** Monitor health checks (tmux, hcom, disk space).
-   **Active Agents:** See which agents are currently registered with `hcom`.
-   **Configuration Summary:** Quickly review your active LLMs and backends.
-   **Recent Activity:** A live log viewer for environment events.

### 3. Quick Actions
Launch core components directly from the browser:
-   **Launch Dashboard:** Starts the unified monitoring and command layout.
-   **Run Pre-flight Checks:** Validate your environment's readiness.
-   **Recover Session:** Automatically clean up corrupted `tmux` sessions.

### 4. Configuration Editor
A centralized interface to modify your `config.toml` without manual file editing. All changes are validated against the system schema to prevent errors.

### 5. Log Viewer
A dedicated page for streaming system logs, filtered by severity (INFO, SUCCESS, WARN, ERROR).

## API Endpoints

The Web UI provides a REST API for programmatic access:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | System health check with tmux, hcom, and disk status |
| `/api/preflight` | GET | Comprehensive pre-flight checks |
| `/api/session/status` | GET | Get tmux session status |
| `/api/session/recover` | POST | Recover from crashed session |
| `/api/agents` | GET | List active agents from hcom |
| `/api/config` | GET | Get current configuration |
| `/api/config` | PUT | Update configuration |
| `/api/config/validate` | POST | Validate configuration against schema |
| `/api/status` | GET | Get system status |
| `/api/dashboard/launch` | POST | Launch the dashboard |
| `/api/logs` | GET | Get recent logs |
| `/api/profiles` | GET | Get available configuration profiles |

## Troubleshooting

### Session Corrupted
If the Web UI reports that a dashboard session already exists but is unresponsive, use the **Recover Session** button on the Dashboard page. This will:
-   Kill the existing `tmux` session.
-   Remove stale lock files.
-   Clean up orphaned agent processes.

### Backend Connectivity
Ensure your API keys are correctly set in the environment or the `.ai-colab-env` file. The Web UI's **Pre-flight Checks** can help verify connectivity to NVIDIA NIM or RunPod backends.

### Missing Dependencies
If health checks fail, verify that tmux and hcom are installed:
```bash
# Check tmux
tmux -V

# Check hcom
hcom --version
```

## Version

**Current Version:** 2.0.0 (Enhanced)

**Features:**
- Enhanced health checks with system status
- Pre-flight API endpoint
- Session management and recovery
- Real-time agent monitoring
- Configuration validation with JSON Schema
