# ai-colab Installation Guide

ai-colab provides a flexible installation experience with three distinct pathways.

## Pathway 1: Interactive CLI Wizard (Recommended)
Best for: Developers who want a guided setup in their native terminal environment.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/ai-colab/ai-colab.git
    cd ai-colab
    ```

2.  **Run the master installer with the wizard flag:**
    ```bash
    ./install.sh --wizard
    ```

3.  **Follow the interactive steps:**
    -   Select your installation profile (Minimal, Standard, or Full).
    -   Enable and configure LLM agents (Gemini, Qwen, etc.).
    -   Select a compute backend (Local, NVIDIA NIM, or RunPod).
    -   Enable modular addons (Atari-8bit).

4.  **Launch the dashboard:**
    ```bash
    ./launch.sh
    ```

## Pathway 2: Docker & Web UI
Best for: Users who prefer a browser-based interface or consistent containerized environments.

1.  **Start the environment using Docker Compose:**
    ```bash
    docker-compose up -d
    ```

2.  **Access the Web UI:**
    Open `http://localhost:8080` in your browser.

3.  **Complete the setup:**
    Follow the Web UI's setup wizard to configure your LLMs and backends.

4.  **Start collaborating:**
    Use the browser-based dashboard to launch agents and monitor project progress.

## Pathway 3: Quick/Auto Install
Best for: CI/CD or experienced users who want a standard setup without interactivity.

1.  **Run the auto-installer:**
    ```bash
    ./install.sh --auto
    ```
    *This will apply standard defaults and skip all interactive prompts.*

---

## Project Migration (v3.0)
If you are moving an existing AI project into the ai-colab ecosystem, use the automated **Project Migration Tool**.

### Features
-   **Automated Detection:** Scans for MCP configurations, product plans, and KB artifacts.
-   **Safe Integration:** Creates automatic backups before importing existing files.
-   **Seamless Onboarding:** Merges configurations into the unified `config.toml`.
-   **Launcher Integration:** `launch.sh` will automatically detect and prompt for migration if existing integrations are found.

### Manual Usage
To trigger a migration manually:
```bash
./scripts/migrate-project.sh
```

---

## Post-Installation Management

### Reconfiguration
You can modify your setup at any time by running:
```bash
./install.sh --reconfigure
```
*Or by visiting the **Settings** page in the Web UI.*

### Unified Configuration
All settings are stored in `config/config.toml` and validated against `config/config.schema.json`. You can manually inspect these files, but we recommend using the configuration tools to avoid errors.

### Compute Backends
-   **Local:** Uses local model servers (vLLM or Ollama).
-   **NVIDIA NIM API:** Leverages hosted NVIDIA NIM endpoints for high-power reasoning (requires `NVIDIA_API_KEY`).
-   **RunPod:** Deploys remote compute spokes to RunPod GPU instances (requires `RUNPOD_API_KEY`).
