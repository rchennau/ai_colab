# Plan: nemoclaw NVIDIA NIM Integration

## Phase 1: Core Integration
- [ ] Task: Update `scripts/nemo-cli.py` with improved error handling and specific `nemoclaw` defaults.
- [ ] Task: Create `scripts/nemoclaw-hcom.sh` using the `agent-wrapper.sh`.
- [ ] Task: Update `scripts/agent-wrapper.sh` to explicitly support `nemoclaw` as a top-level agent identity.

## Phase 2: Configuration & Credentials
- [ ] Task: Ensure `launch.sh` correctly prompts for and exports the `NVIDIA_API_KEY` for the `nemoclaw` session.
- [ ] Task: Add a verification step to `scripts/cicd-deploy-nvidia.sh` to test the `nemoclaw` model availability.

## Phase 3: Specialized Prompting
- [ ] Task: Create `system-prompts/nemoclaw.md` with architectural lead instructions.
- [ ] Task: Integrate this prompt into the `nemoclaw` launch sequence.

## Phase 4: Verification
- [ ] Task: Launch the `nemoclaw` agent and verify its status in the `hcom` TUI.
- [ ] Task: Send an architectural query to `@nemoclaw` and verify the NVIDIA NIM response.
