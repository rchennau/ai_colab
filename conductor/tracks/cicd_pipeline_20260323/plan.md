# Plan: CI/CD Pipeline for Agent Deployment

## Phase 1: Containerization
- [ ] Task: Create `Dockerfile` optimized for ai-colab agents.
- [ ] Task: Implement `scripts/cicd-build.sh`.
- [ ] Task: Verify the container can run `hcom` and Gemini/Claude CLI internally.

## Phase 2: RunPod Integration
- [ ] Task: Develop `scripts/cicd-deploy-runpod.sh`.
- [ ] Task: Use `curl` or `runpod-python` to interact with the RunPod API.
- [ ] Task: Securely pass environment variables (API keys, HCOM relay) to the remote pod.

## Phase 3: NVIDIA Integration
- [ ] Task: Develop `scripts/cicd-deploy-nvidia.sh`.
- [ ] Task: Interface with NVIDIA NGC or NIM API if applicable.

## Phase 4: Fleet Management
- [ ] Task: Add a `!fleet-expand` command to the Conductor.
- [ ] Task: Update the Dashboard to show remote vs local agent status.
- [ ] Task: Verify remote `hcom` connectivity.
