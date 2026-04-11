# Implementation Plan: MQTT Security Hardening (P16.6)

## Execution Order

```
P16.6.1 (Mosquitto Broker) ──→ P16.6.2 (TLS)
                                    ↓
                              P16.6.3 (Auth)
                                    ↓
                              P16.6.4 (Documentation)
```

---

## Phase P16.6.1: Self-Hosted Mosquitto Broker

### Step 1: Create Docker Mosquitto Configuration
- `docker/mosquitto/mosquitto.conf` — Basic broker config
- `docker/mosquitto/entrypoint.sh` — Initialize passwd file on first run
- `docker-compose.yml` — Add `mqtt` service with profile

### Step 2: Update docker-compose.yml
- Add mqtt service with eclipse-mosquitto:2.0
- Configure volume mounts (config, certs, passwd, data)
- Add health check
- Set resource limits (256MB RAM, 0.5 CPU)
- Add `profiles: ["mqtt"]` for opt-in deployment

### Step 3: Test Mosquitto Service
- `docker compose --profile mqtt up -d`
- Verify health check passes
- Test basic publish/subscribe
- Verify data persistence across restart

---

## Phase P16.6.2: TLS Encryption

### Step 1: Create Certificate Generation Script
- `scripts/generate-certs.sh` — Generate self-signed certs
- Output: `docker/mosquitto/certs/ca.crt`, `server.crt`, `server.key`
- Auto-run on first `docker compose up`

### Step 2: Update Mosquitto Config for TLS
- Enable TLS listener on port 8883
- Disable non-TLS listener (1883)
- Point to certificate files

### Step 3: Update config.toml
- Add `relay.tls_enabled = true`
- Add `relay.ca_cert`, `relay.client_cert`, `relay.client_key`
- Update `relay.url` to `mqtts://localhost:8883`

### Step 4: Test TLS
- Verify TLS handshake
- Test connection with certificates
- Verify non-TLS connection rejected

---

## Phase P16.6.3: Authentication

### Step 1: Update Mosquitto Config for Auth
- Set `allow_anonymous false`
- Point `password_file` to `/mosquitto/config/passwd`

### Step 2: Update Entrypoint Script
- Generate default admin credentials if passwd file missing
- Store credentials in blackboard via `config-manager`
- Credentials retrievable by agents at registration

### Step 3: Update config.toml
- Add `relay.username` and `relay.password`
- Mark as auto-generated (empty on first run)

### Step 4: Test Authentication
- Verify anonymous connection rejected
- Test auth with generated credentials
- Verify credential retrieval works

---

## Phase P16.6.4: Documentation

### Step 1: Create Setup Guide
- `docs/mqtt-security-setup.md`
- Quick start section
- Production deployment section
- Troubleshooting section
- Migration guide from public broker

### Step 2: Update Existing Docs
- `README.md` — Mention MQTT security setup
- `conductor/knowledge_base_map.md` — Add MQTT security entry

### Step 3: Test Documentation
- Follow quick start guide end-to-end
- Verify all commands work as documented
- Update any errors found

---

## Development Workflow

1. **Create track branch:** `git checkout -b track/mqtt-security-p16.6`
2. **Write tests first** (TDD)
3. **Implement feature**
4. **Run tests** — must pass
5. **Commit** — conventional commit message
6. **Update this plan** — mark task complete
7. **Conductor approval** — via `!approve` command

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Mosquitto container fails to start | Health check with auto-restart, detailed logging |
| TLS certificate issues | Auto-generation fallback, clear error messages |
| Auth breaks existing agents | Dual-mode support during migration, credential auto-provisioning |
| Port conflicts (8883) | Configurable port in docker-compose.yml |
| Data loss on container restart | Persistent volume for Mosquitto data |
