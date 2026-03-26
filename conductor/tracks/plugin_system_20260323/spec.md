# Track: Generic Module Plugin System

## 1. Objective
Transform ai-colab into a fully modular framework where domain-specific functionality (like platform-specific tools) can be added or removed via a standardized manifest-based plugin system.

## 2. Specification

### 2.1 Module Manifest (`module.toml`)
Each module must contain a `module.toml` in its root directory with the following structure:
```toml
[module]
id = "example-module"
name = "Example Addon"
description = "Specialized tools for a specific domain."
version = "1.0.0"

[env]
ENABLE_EXAMPLE_MODULE = "true"

[hooks]
# Commands added to the Conductor
conductor_commands = [
    { trigger = "!custom-cmd", script = "scripts/custom-handler.sh" }
]

# Sections added to the Conductor Dashboard TUI
dashboard_sections = [
    { name = "Domain Status", type = "table", source = "sql:SELECT status FROM domain_table..." }
]
```

### 2.2 Dynamic Registration
- **Installer**: `install.sh` should scan `modules/*/module.toml` and present a menu of available modules.
- **Launcher**: `launch.sh` should scan for installed modules and export their defined environment variables.
- **Conductor**: `conductor-workflow.sh` should dynamically register commands from all active modules.
- **Dashboard**: `conductor-dashboard.sh` should render sections based on the active modules' manifests.

## 3. Success Criteria
- [x] No hardcoded domain-specific logic remains in the core scripts.
- [x] A new module can be added by simply placing it in the `modules/` directory.
- [x] Conductor `!help` dynamically lists commands from active modules.
- [x] Dashboard UI adapts its sections based on active plugins.
