# Phase 22: Federated Intelligence Blueprint
**Status: DEFERRED**

This document serves as the comprehensive architectural, product, and testing blueprint for Phase 22. Implementation is currently deferred, but this design provides the roadmap for transforming `ai-colab` from a localized orchestration tool into a globally networked, multi-hub collaboration platform.

---

## 1. Product Plan

### 1.1 Vision & Theme
**Theme:** "Networked Organizations" / "Cross-Hub Collaboration"

As `ai-colab` scales, individual developers, disparate teams, or distinct organizations will run their own isolated Orchestration Hubs to maintain data sovereignty and control costs. The vision for Phase 22 is to enable these isolated hubs to securely discover each other, negotiate, and share specialized agent capabilities—shifting the paradigm from a single "Fleet Manager" to a "Decentralized Network of Intelligence."

### 1.2 Target Audience
*   **Enterprise Teams:** Distinct departments (e.g., Frontend, Backend, DevOps) running separate Hubs but needing to collaborate on cross-cutting features.
*   **Open-Source Communities:** Independent developers pooling specialized local agents (e.g., someone hosting a massive 70B parameter architecture model) to assist on community tracks.
*   **Consultancies:** Firms providing specialized "agent-as-a-service" capabilities to client Hubs.

### 1.3 Key Features
1.  **Trust Federation:** A secure mechanism to establish trust between distinct Hubs (public key exchange).
2.  **Autonomous Task Bidding (RFP):** When a Conductor lacks a local agent with the required capability (e.g., high "architecture" score), it broadcasts a Request for Proposal (RFP) to the federation. Remote Hubs automatically bid based on their agents' availability and token costs.
3.  **Secure State Handoff:** The ability to securely package and transmit a specific subset of the Blackboard (context, memory, tracks) to a remote Hub for task execution, and synchronize the results back.
4.  **Global Fleet Observability:** A unified view in the Dashboard and WebUI showing the health and latency of both local and remote agents.

### 1.4 Success Metrics
*   **Inter-operability:** Successful end-to-end completion of a track requiring back-and-forth collaboration between agents on two distinct, physically separated Hubs.
*   **Security:** Zero unauthorized access or data leakage between untrusted Hubs (enforced via strict mTLS/cryptographic signing).

---

## 2. Engineering Plan

The engineering effort is divided into three core pillars: Messaging, Orchestration, and Observability.

### P22.1: Hub-to-Hub Messaging Protocol (Secured `hcom` Relay)
The current `hcom` implementation relies on local named pipes and basic HTTP. This must be hardened for traversing public networks.

1.  **Transport Layer Security:**
    *   Upgrade the `hcom` server to support WebSockets over TLS (WSS) or gRPC with mutual TLS (mTLS).
    *   Implement payload signing using Ed25519 or ECDSA keys to guarantee message provenance.
2.  **Federation Registry (`config/federation.toml`):**
    *   Introduce a new configuration schema to manage known peers.
    *   Schema: `[peers.<hub_id>] url="wss://remote.example.com" pubkey="<base64_key>"`
3.  **Addressing Scheme:**
    *   Extend the `hcom send` addressing model from `@<agent_name>` to `@<hub_id>:<agent_name>` (e.g., `@ops_team:deploy_bot`).
    *   Introduce a broadcast address: `@federation` (sends to all trusted peers).

### P22.2: Task Negotiation & Bidding Engine
The Conductor must evolve from a static dispatcher into a dynamic marketplace negotiator.

1.  **RFP Generation (`scripts/conductor-workflow.sh`):**
    *   Update `agent_select_best` to recognize when local agents fall below a minimum capability threshold for a track.
    *   Generate a structured RFP JSON payload (Track ID, required capability, context window size, max budget).
    *   Broadcast the RFP via `hcom send @federation --intent rfp`.
2.  **The Bidding Daemon (`scripts/federation.py`):**
    *   A new background service that listens for incoming RFPs.
    *   It evaluates the RFP against the local `config/agent-capabilities.json` and active agent load.
    *   If a match is found, it calculates a bid score (based on capability match and cost) and replies to the originating Hub.
3.  **State Handoff & Synchronization:**
    *   Once the originating Conductor accepts a bid, it isolates the relevant Blackboard keys (e.g., `track_status_<slug>`, memory pointers).
    *   It transmits this state packet to the remote Hub, which temporarily registers a "proxy track" in its own Blackboard.
    *   Upon task completion, the remote Hub transmits a state delta back to the origin.

### P22.3: Distributed Fleet Observability
1.  **Remote Health Tracking:**
    *   Remote Hubs periodically broadcast summarized health metrics for agents involved in federated tasks.
    *   Local `hcom-kv` stores these under a specific namespace: `remote_health_<hub_id>_<agent_name>`.
2.  **Dashboard Integration:**
    *   Update `scripts/conductor-dashboard.sh` to render a new "Federated Agents" section, displaying the remote Hub name, agent status, and inter-hub latency.

---

## 3. Testing Plan

Given the complexity of distributed systems, testing must be rigorous and heavily rely on simulated networks.

### 3.1 Unit Testing (Isolated Components)
*   **Protocol Security (`tests/test_federation_crypto.py`):**
    *   Verify that messages signed with an unregistered public key are immediately dropped.
    *   Verify that payload tampering invalidates the signature.
*   **Bidding Algorithm (`tests/test_bidding_engine.py`):**
    *   Provide mocked RFPs and local capability files to the bidding engine.
    *   Assert that the engine correctly calculates bids, prioritizing highly capable agents and rejecting RFPs that exceed local limits.

### 3.2 Integration Testing (Multi-Instance)
*   **Dual-Hub Simulation (`tests/test_federation_handshake.sh`):**
    *   A bash harness that spins up two distinct `ai-colab` Hub instances on different localhost ports (e.g., 8080 and 8081) with separate `.ai-colab-prefs` and `.hcom` directories.
    *   Script a public key exchange between the two Hubs.
    *   Assert that a ping message sent from Hub A is received and acknowledged by Hub B.

### 3.3 End-to-End (E2E) System Testing
*   **The Handoff Lifecycle (`tests/e2e_federated_task.sh`):**
    1.  Hub A initializes a track requiring "DevOps" capabilities (which it lacks).
    2.  Hub A broadcasts an RFP.
    3.  Hub B (configured with a mock DevOps agent) receives the RFP and submits a bid.
    4.  Hub A accepts the bid.
    5.  Hub B executes a mock script representing the task and updates its proxy state to "Complete".
    6.  Hub B synchronizes the state back to Hub A.
    7.  Assert that Hub A's Conductor marks the original track as "pr_ready" or "Done".
*   **Chaos Testing (`tests/e2e_federation_partition.sh`):**
    *   Initiate a task handoff, then intentionally sever the network connection (e.g., kill the port mapping) midway through execution.
    *   Assert that Hub A eventually times out the remote task, penalizes Hub B's reliability score, and re-broadcasts the RFP.
