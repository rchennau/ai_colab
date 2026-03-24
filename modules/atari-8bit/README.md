# Addon Module: Atari-LX Development

This module provides specialized tools and configurations for **Atari 8-bit Engineering**, featuring deep integration with 6502 assembly development, hardware awareness, and automated performance tracking.

## 🌟 Features

-   **Visual Memory Map Generator (`!memory-map`)**: Parses `cc65` map files to generate a visual ASCII representation of the Atari's 64KB address space.
-   **Performance Trending (`!perf-trend`)**: Persistently tracks cycle counts for assembly routines across commits and alerts the team of regressions.
-   **Visual Debugging (`!screenshot`)**: Automatically captures and syncs the Atari800 emulator screen state to the team via `hcom` and Google Chat.
-   **Hardware Constants**: Automatically populates the Shared Blackboard with standard Atari hardware register addresses (ANTIC, GTIA, POKEY, etc.).
-   **Technical Debate Mode**: Specialized wrapper for starting multi-agent implementation debates with hardware context pre-injected.

## 🚀 Setup

### 1. Installation
During the main `ai-colab` installation, choose **Yes** when prompted to install the Atari-LX module.

**Dependencies:**
-   `cc65`: The 6502 C/Assembly toolchain.
-   `atari800`: For emulator integration and screen capture.

### 2. Enablement
When launching the dashboard via `./launch.sh`, choose **Yes** to enable the Atari-LX module. This activates the specialized Conductor commands and TUI sections.

## 🛠️ Specialized Commands

| Command | Purpose |
|---------|---------|
| `!screenshot` | Captures current emulator state. |
| `!memory-map` | Generates visual memory allocation report. |
| `!profile <file>` | Analyzes 6502 assembly for cycle counts. |
| `!perf-trend <routine>`| Shows historical performance trend. |

## 📋 Best Practices

### **Atari-Dev-Agent MCP**
When this module is active, agents are pre-configured with the **atari-dev-agent** MCP server. This provides specialized tools for:
-   `validate_6502_code(code)`: Checks for common assembly errors.
-   `count_cycles(code)`: Exact cycle timing for scanline optimization.
-   `search_kb(query)`: Search the Atari-LX knowledge base.
-   `analyze_atari_screen(image_path)`: Visual debugging via OCR/Vision.

### **Role-Based Intelligence**
The agents take on specialized hardware roles:
-   **Qwen**: Assembly & Hardware Expert (Timing-critical code).
-   **DeepSeek**: Logic & Optimization Specialist (Algorithms & C).
-   **Gemini**: Architect & Orchestrator.

---
*Part of the ai-colab modular ecosystem.*
