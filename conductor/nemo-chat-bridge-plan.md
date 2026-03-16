# Implementation Plan: NVIDIA NeMo and Google Chat Messenger Bridge

This plan introduces NVIDIA NeMo as a high-level architectural agent and creates a bridge to Google Chat for remote monitoring and updates.

## Phase 1: NVIDIA NeMo Integration

### 1.1 `scripts/nemo-hcom.sh`
Create a wrapper for NVIDIA NeMo (Nemotron) using an OpenAI-compatible API (e.g., NVIDIA API Catalog or a local NIM).

**Functionality:**
- Register as `nemo-$$` with `hcom start`.
- Pulse the session with `hcom listen`.
- Forward arguments to the `nemo` CLI or a specialized `curl`/`python` caller.
- Support default model: `nvidia/llama-3.1-nemotron-70b-instruct`.

### 1.2 `config.toml` Update
Add a `[launch.nemo]` section to define default arguments and system prompts.

## Phase 2: Google Chat Messenger Bridge

### 2.1 `scripts/hcom-chat-bridge.sh`
Create a persistent bridge script that monitors `hcom` events and forwards them to a Google Chat space.

**Logic:**
1. **Startup**: Locate or create a Google Chat space named "Atari-LX Multi-Agent".
2. **Subscription**: Use `hcom events sub` to listen for critical events (e.g., `plan-sync`, `visual-debug`, `life_action=batch_launched`).
3. **Forwarding Loop**:
   - For each new event, format a Google Chat markdown message.
   - Use the `chat.sendMessage` tool to post the update.
   - (Optional) Listen for replies in Chat and inject them back into `hcom` as external messages.

### 2.2 Dashboard Integration
Add a `--bridge` flag to `scripts/dashboard-launch.sh` to start the Google Chat bridge in a background pane.

## Phase 3: Verification & Testing

### 3.1 NeMo Test
Run `hcom run nemo --help` and verify it appears in `hcom list`.

### 3.2 Bridge Test
1. Start the bridge: `bash scripts/hcom-chat-bridge.sh`.
2. Send an `hcom` message: `hcom send @all -- "Remote update test"`.
3. Verify the message appears in the user's Google Chat.

## Key Files
- `scripts/nemo-hcom.sh` (New)
- `scripts/hcom-chat-bridge.sh` (New)
- `scripts/dashboard-launch.sh` (Modified)
- `config.toml` (Modified)
