# Plan: Multi-Backend Compute Selection (Cloud/Edge)

## Phase 1: Interactive Installation
- [ ] Task: Update `install.sh` to include a backend selection menu.
- [ ] Task: Implement credential collection for NVIDIA and RunPod.
- [ ] Task: Save backend preferences to `.ai-colab-prefs` and `config.toml`.

## Phase 2: Launcher Integration
- [ ] Task: Update `launch.sh` to display the active backend.
- [ ] Task: Add a prompt to switch backends at launch time.
- [ ] Task: Export the correct `COMPUTE_BASE_URL` based on the selection.

## Phase 3: Agent Routing
- [ ] Task: Update `scripts/agent-wrapper.sh` to respect `COMPUTE_BACKEND`.
- [ ] Task: Ensure NeMo and Claude agents use the centralized compute configuration.

## Phase 4: Verification
- [ ] Task: Test with dummy API keys to ensure environment variables are exported correctly.
- [ ] Task: Verify that local fallback works if no cloud backend is selected.
