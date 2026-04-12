# Federated Intelligence (Phase 22) Implementation Plan

## Background & Motivation
As `ai-colab` usage scales, individual developers or organizations will run their own isolated Orchestration Hubs. To enable large-scale, cross-organizational collaboration without centralizing infrastructure, hubs must be able to securely communicate, share skills, and negotiate tasks. This shifts `ai-colab` from a localized "Fleet Manager" to a "Networked Organization."

## Phase 22.1: Hub-to-Hub Messaging Protocol
1. **Secured `hcom` Relay**:
   * Currently, `hcom` operates via local named pipes or simple HTTP for MCP. We need an authenticated, encrypted protocol (e.g., gRPC over mTLS or secured WebSockets) for long-distance communication.
   * Implement a mechanism to exchange public keys between trusted Hubs to form a federation.
2. **Federation Manifest (`config/federation.toml`)**:
   * Allow users to register known external Hubs (`[peers] hub_alpha = { url = "https://alpha.example.com", pubkey = "..." }`).

## Phase 22.2: Task Negotiation & Bidding
1. **Broadcast Request for Proposal (RFP)**:
   * When a Conductor receives a task it cannot fulfill locally (e.g., missing a specific skill or capability score), it broadcasts an RFP to its federated peers.
   * `hcom send @fleet --intent rfp --task "Need Senior React Dev for Track X"`
2. **Capability Bidding**:
   * Remote Conductors evaluate the RFP against their local `agent-capabilities.json`.
   * If a remote agent matches, the remote Conductor sends a bid (including estimated cost and availability).
3. **Task Handoff**:
   * The originating Conductor accepts the best bid and securely transfers the necessary context (Blackboard state subset, Track info) to the remote Hub.

## Phase 22.3: Distributed Fleet Health
1. **Global Dashboard**:
   * Update `scripts/conductor-dashboard.sh` and the Web UI to visualize the health and status of both local and federated agents.
   * Display which Hub an agent belongs to and its latency across the federation network.

## Timeline
- **Phase 22.1**: Implement secure inter-hub messaging in `hcom` and the `federation.toml` configuration.
- **Phase 22.2**: Develop the RFP/Bidding protocol in `scripts/conductor-workflow.sh`.
- **Phase 22.3**: Update observability tools to reflect distributed fleet status.
