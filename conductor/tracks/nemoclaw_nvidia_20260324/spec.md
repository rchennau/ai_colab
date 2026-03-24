# Track: nemoclaw NVIDIA NIM Integration

## 1. Objective
Fully integrate and optimize the `nemoclaw` agent to use NVIDIA's NIM API, providing high-power architectural reasoning and specialized multi-agent coordination capabilities.

## 2. Specification

### 2.1 Model Configuration
- **Model Name**: `nvidia/llama-3.1-nemotron-70b-instruct` (or latest recommended for nemoclaw).
- **Backend**: NVIDIA NIM API via `https://integrate.api.nvidia.com/v1`.
- **Credentials**: `NVIDIA_API_KEY` sourced from project configuration or environment.

### 2.2 CLI Wrapper (`scripts/nemo-cli.py`)
- Enhance the wrapper to support specific `nemoclaw` system prompts.
- Implement token usage tracking if available via API.
- Optimize streaming output for hcom integration.

### 2.3 hcom Registration
- Create `scripts/nemoclaw-hcom.sh` as a specialized wrapper for the agent.
- Ensure the agent registers with the name `nemoclaw` by default.

## 3. Success Criteria
- [ ] `nemoclaw` can be launched and successfully registers with `hcom`.
- [ ] Commands sent to `nemoclaw` are processed using the NVIDIA NIM API.
- [ ] The agent correctly sources the `NVIDIA_API_KEY` from the environment.
