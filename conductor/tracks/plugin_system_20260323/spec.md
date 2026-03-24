# Track: Generic Module Plugin System

## 1. Objective
Transform ai-colab into a fully modular framework where domain-specific functionality (like Atari-LX) can be added or removed via a standardized manifest-based plugin system.

## 2. Specification

### 2.1 Module Manifest (`module.toml`)
Each module must contain a `module.toml` in its root directory with the following structure:
```toml
[module]
id = "atari-lx"
name = "Atari-LX Development"
description = "Specialized tools for 6502 assembly and Atari hardware."
version = "1.0.0"

[env]
ENABLE_ATARI_LX = "true"

[scripts]
install = "scripts/install-deps.sh" # Optional
init = "scripts/init-blackboard.sh" # Optional

[hooks]
# Commands added to the Conductor
conductor_commands = [
    { trigger = "!screenshot", script = "scripts/hcom-atari-screen.sh" },
    { trigger = "!memory-map", script = "scripts/atari-mem-map.sh" }
]

# Sections added to the Conductor Dashboard TUI
dashboard_sections = [
    { name = "Latest Performance", type = "table", source = "sql:SELECT routine, cycles FROM performance..." },
    { name = "Memory Allocation", type = "text", source = "file:conductor/reports/memory_map.txt" }
]
```

### 2.2 Dynamic Registration
- **Installer**: `install.sh` should scan `modules/*/module.toml` and present a menu of available modules.
- **Launcher**: `launch.sh` should scan for installed modules and export their defined environment variables.
- **Conductor**: `conductor-workflow.sh` should dynamically register commands from all active modules.
- **Dashboard**: `conductor-dashboard.sh` should render sections based on the active modules' manifests.

## 3. Success Criteria
- [ ] No hardcoded Atari-LX logic remains in the core scripts.
- [ ] A new module can be added by simply placing it in the `modules/` directory.
- [ ] Conductor `!help` dynamically lists commands from active modules.
- [ ] Dashboard UI adapts its sections based on active plugins.
