# The Plugin Economy (Phase 21) Implementation Plan

## Background & Motivation
Currently, modules are manually copied into the `modules/` directory. To scale the ecosystem and enable community contributions, `ai-colab` needs a centralized registry, discovery mechanics, and strict sandboxing for third-party plugins.

### Architectural Distinction: Modules vs. Agent Extensions
It is critical to distinguish `ai-colab` Modules from the native extension capabilities found in individual LLM CLIs (like Gemini extensions, Claude tools, or raw MCP servers):

*   **Agent Extensions (LLM-Level):** Give a *single* agent the ability to perform a specific action (e.g., read a file, execute a bash script, search the web). They are bounded by the context and execution loop of that specific LLM process.
*   **ai-colab Modules (Orchestration-Level):** Define entire *multi-agent workflows* and environment configurations. A module can:
    *   Inject specialized system prompts into *all* spawned agents in the fleet.
    *   Create custom UI panes in the tmux dashboard (e.g., a real-time memory map visualizer).
    *   Define periodic background hooks (e.g., a watchdog that analyzes performance trends every 5 minutes).
    *   Orchestrate complex interactions between *different* models (e.g., forcing a debate between Gemini and Claude on a specific topic, like the `atari-debate.sh` script).

In short: Extensions are tools for agents. Modules are blueprints for the entire orchestration environment.

## Phase 21.1: Standardized Module Manifests
1. **Manifest Schema**:
   * Extend `config/config.schema.json` or create a new `module.schema.json` to validate `module.toml`.
   * Add fields for `version`, `author`, `dependencies` (Python packages via `uv`), and `permissions` (`network`, `file_system`, `environment`).

## Phase 21.2: Module Registry & Discovery
1. **Registry Repository**:
   * Create an official GitHub repository (e.g., `ai-colab/plugin-registry`) containing an `index.json` that maps plugin names to their Git repository URLs and versions.
2. **CLI Commands (`scripts/module-marketplace.sh`)**:
   * `ai-colab module search <query>`: Fetches the central `index.json` and searches descriptions.
   * `ai-colab module info <name>`: Displays the plugin's metadata, dependencies, and requested permissions.

## Phase 21.3: Installation & Sandboxing
1. **Installation Workflow**:
   * `ai-colab module install <name>`: Clones the plugin repo into `modules/<name>`.
   * Parses the `module.toml` for permissions. If `permissions` are requested, prompt the user for explicit approval (Y/n).
2. **Execution Environment**:
   * During installation, if the plugin has Python dependencies, `uv` is used to create an isolated virtual environment specifically for that module (`modules/<name>/.venv`).
   * When `scripts/module-manager.sh` executes a module command, it uses this isolated `.venv` instead of the global one, preventing dependency conflicts.
   * Alternately, leverage the Phase 19 Docker infrastructure to run the plugin in an isolated container.

## Timeline
- **Phase 21.1**: Define and validate the extended `module.toml` schema.
- **Phase 21.2**: Build the registry index and the `search/info` CLI commands.
- **Phase 21.3**: Implement the `install` command, permission prompts, and `uv` sandboxing.
