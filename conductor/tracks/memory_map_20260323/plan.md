# Plan: Visual Memory Map Generator

## Phase 1: Map Parsing & Data Extraction
- [ ] Task: Create `scripts/atari-mem-map.sh` (Base skeleton).
- [ ] Task: Add `cc65` map file parser logic to extract segments and addresses.
- [ ] Task: Integrate with `scripts/hcom-atari-sync.sh` to populate the Blackboard with segment bounds.

## Phase 2: ASCII Visualization
- [ ] Task: Implement the 64KB address space generator.
- [ ] Task: Map standard Atari hardware registers to the ASCII visualization.
- [ ] Task: Overlay project-specific segments (CODE, DATA, BSS) on the map.
- [ ] Task: Add color coding or legend for RAM vs. ROM vs. Hardware.

## Phase 3: Integration & Reporting
- [ ] Task: Add `!memory-map` command to `scripts/conductor-workflow.sh`.
- [ ] Task: Implement a reporter that saves the map to `conductor/reports/memory_map.txt`.
- [ ] Task: Verify that the Conductor can broadcast the map to `@all`.

## Phase 4: Verification & Testing
- [ ] Task: Create `tests/test_memory_map.sh` with mock map data.
- [ ] Task: Verify accuracy of addresses vs. the ASCII visualization.
