# Track: Multi-Backend Compute Selection (Cloud/Edge)

## 1. Objective
Enable users to choose the compute backend for high-power agents (like NeMo or Claude) during installation and launch, supporting NVIDIA API, RunPod, and Local Servers.

## 2. Specification

### 2.1 Backend Options
- **NVIDIA API**: Use NVIDIA's NIM / Hosted API endpoints.
- **RunPod**: Dynamically deploy or connect to a RunPod instance.
- **Local Server**: Connect to a local vLLM or Ollama instance.

### 2.2 Interactive Selection
- **install.sh**: Prompt the user to configure their preferred compute backend and store credentials (API keys) in `config.toml`.
- **launch.sh**: Allow switching or confirming the backend before starting the dashboard.

### 2.3 Environment Variables
- `COMPUTE_BACKEND`: `nvidia`, `runpod`, or `local`.
- `NVIDIA_API_KEY`: For NVIDIA hosted services.
- `RUNPOD_API_KEY`: For RunPod orchestration.
- `COMPUTE_BASE_URL`: The endpoint for the selected backend.

## 3. Success Criteria
- [ ] User can select backend during `install.sh`.
- [ ] Credentials are securely stored or referenced.
- [ ] Agents correctly route requests based on `COMPUTE_BACKEND`.
