# Plan: Docker Refinement & Verification (Phase 3)

## 1. Objective
Refine the existing Docker configuration to ensure full integration with the new `config-manager.sh` and provide a robust health-check mechanism for the Web UI.

## 2. Refinements

### 2.1 Refine `docker/entrypoint.sh`
- Replace manual `sed` commands with `scripts/config-manager.sh` calls for environment overrides.
- Ensure `init_config_from_env` correctly sets up the initial `config.toml` if missing.
- Add validation step using `config-manager.sh validate` before starting services.

### 2.2 Refine `webui/app.py`
- Update the `/health` endpoint to return HTTP 503 if `critical_issues` are found, ensuring `curl -f` in Docker/Compose correctly identifies unhealthy states.

### 2.3 Optimize `Dockerfile`
- Ensure all necessary tools for `config-manager.sh` (like `python3`, `toml`, `jsonschema`) are available in the image. (Already present, but worth a double-check).

## 3. Verification Plan

### 3.1 Automated Tests
- Run `tests/test_docker_core.sh` to verify the container build and basic service availability.
- Run `tests/test_config_manager.sh` inside the container (via `docker exec`) to ensure it works in the Ubuntu environment.

### 3.2 Manual Verification
- Start the environment using `docker-compose up -d`.
- Verify the Web UI is accessible at `http://localhost:8080`.
- Check the health status via `docker inspect ai-colab`.

---

## 4. Tasks

- [ ] Task: Refactor `docker/entrypoint.sh` to use `config-manager.sh`.
- [ ] Task: Update `webui/app.py` health check status codes.
- [ ] Task: Verify Docker image build and health check.
- [ ] Task: Update `conductor/tracks.md` and `conductor/tracks/enhanced_install_launch_20260324/plan.md`.
