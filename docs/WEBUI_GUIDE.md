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
-   Configure compute backends.
-   Register modular addons.

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

## Troubleshooting

### Session Corrupted
If the Web UI reports that a dashboard session already exists but is unresponsive, use the **Recover Session** button on the Dashboard page. This will:
-   Kill the existing `tmux` session.
-   Remove stale lock files.
-   Clean up orphaned agent processes.

### Backend Connectivity
Ensure your API keys are correctly set in the environment or the `.ai-colab-env` file. The Web UI's **Pre-flight Checks** can help verify connectivity to NVIDIA NIM or RunPod backends.
