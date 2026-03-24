# Track: Visual Memory Map Generator

## 1. Objective
Create a tool that provides a visual overview of the Atari 8-bit memory allocation for the current project. This helps developers identify memory fragmentation, overlaps, and available space.

## 2. Specification

### 2.1 Artifact Parsing
- The tool should parse the `cc65` map file (`build/bin/atari-lx.map`) to extract:
  - Memory areas (RAM, ROM, etc.)
  - Segments (CODE, DATA, BSS, etc.) and their start/end addresses.
  - Symbols (optional, but useful for key routines).

### 2.2 Visual Representation (ASCII)
- Generate an ASCII-art bar or table representing the 64KB address space.
- Highlight standard Atari hardware areas (ANTIC, GTIA, POKEY, OS ROM).
- Clearly mark project-specific segments (CODE, DATA, ZEROPAGE).
- Indicate percentage of usage for each memory area.

### 2.3 Integration
- **Command**: `!memory-map`
- The Conductor agent should respond to this command with the ASCII map.
- The map should also be saved to a file: `conductor/reports/memory_map.txt`.

## 3. Implementation Details
- **Tool**: `scripts/atari-mem-map.sh` (or a Python equivalent for better formatting).
- **Backend**: Uses the Blackboard (`atari_addr_*`) as a starting point, but falls back to parsing the map file for detail.

## 4. Success Criteria
- [ ] Tool correctly parses the map file.
- [ ] Generates a legible ASCII representation of the 64KB space.
- [ ] Correctly identifies hardware vs. project segments.
- [ ] Integrated with the Conductor `!memory-map` command.
