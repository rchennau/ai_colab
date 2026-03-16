# Implementation Plan: Deep Atari Integration for hcom

This plan deepens the hardware awareness of the multi-agent team by syncing Atari build artifacts and emulator state into the Shared Blackboard.

## Phase 1: Symbol Synchronization (Hardware Awareness)

### 1.1 `hcom-atari-sync` Tool
Create `scripts/hcom-atari-sync.sh` to parse build artifacts and populate the Blackboard.

**Functionality:**
- Parse `build/bin/atari-lx.map` for segment addresses (CODE, DATA, BSS, etc.).
- Parse `build/bin/atari-lx.sym` (if format permits) or source code for key global labels.
- Populate Blackboard with keys like:
  - `atari_addr_CODE_START`
  - `atari_addr_DATA_START`
  - `atari_addr_BSS_START`
  - `atari_build_mode` (release/development)

### 1.2 Automated Build Integration
Update `Makefile.build` or add a hook to automatically run `hcom-atari-sync.sh` after a successful build.

## Phase 2: Visual Debugging & Screenshots

### 2.1 `hcom-atari-screen` Tool
Create `scripts/hcom-atari-screen.sh` to capture and share emulator state.

**Functionality:**
- Interface with `atari800` or `altirra` (via command line or filesystem hooks) to take a screenshot.
- Use `atari-dev-agent_analyze_atari_screen` (via an agent or standalone call if possible) to generate a text description of the screen.
- Broadcast the description and image path to `@all` via `hcom send`.
- Store the latest screenshot path in the Blackboard: `atari_last_screenshot`.

### 2.2 Shared Debugging Workflow
- An agent can request a screenshot: `@all --intent request -- "Conductor, please take a screenshot of the current emulator state."`
- The Conductor Agent (or a dedicated Tester agent) executes `hcom-atari-screen.sh` and replies with the visual context.

## Phase 3: Hardware Register Quick-Ref

### 3.1 Blackboard Hardware Constants
Populate the Blackboard with standard Atari hardware registers (ANTIC, GTIA, POKEY) upon dashboard startup.
- `atari_reg_RANDOM = $D20A`
- `atari_reg_COLBK = $D01A`
- etc.

This allows agents to quickly reference addresses without searching documentation.

## Phase 4: Verification & Testing

### 4.1 Sync Test
- Run `make build`.
- Verify Blackboard contains correct segment addresses from the map file.

### 4.2 Screenshot Test
- Run emulator.
- Execute `scripts/hcom-atari-screen.sh`.
- Verify a message is sent to `hcom` with the screen analysis.

## Key Files
- `scripts/hcom-atari-sync.sh` (New)
- `scripts/hcom-atari-screen.sh` (New)
- `Makefile.build` (Modified)
- `scripts/dashboard-launch.sh` (Modified to init hardware constants)
