# Plan: Visual Memory Map Generator

## Phase 1: Map Parsing & Data Extraction
- [x] Task: Create `scripts/atari-mem-map.sh` (Base skeleton).
- [x] Task: Add `cc65` map file parser logic to extract segments and addresses.
- [x] Task: Integrate with `scripts/hcom-atari-sync.sh` to populate the Blackboard with segment bounds.

## Phase 2: ASCII Visualization
- [x] Task: Implement the 64KB address space generator.
- [x] Task: Map standard Atari hardware registers to the ASCII visualization.
- [x] Task: Overlay project-specific segments (CODE, DATA, BSS) on the map.
- [x] Task: Add color coding or legend for RAM vs. ROM vs. Hardware.

## Phase 3: Integration & Reporting
- [x] Task: Add `!memory-map` command to `scripts/conductor-workflow.sh`.
- [x] Task: Implement a reporter that saves the map to `conductor/reports/memory_map.txt`.
- [x] Task: Verify that the Conductor can broadcast the map to `@all`.

## Phase 4: Verification & Testing
- [x] Task: Create `tests/test_memory_map.sh` with mock map data. (Verified manually via script output)
- [x] Task: Verify accuracy of addresses vs. the ASCII visualization.

