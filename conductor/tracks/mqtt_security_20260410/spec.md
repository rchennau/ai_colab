# Track: MQTT Security Hardening (P16.6)

**ID:** `mqtt_security_20260410`  
**Created:** 2026-04-10  
**Status:** Pending 📋  
**Assigned:** @conductor, @architect  
**Priority:** Medium  

---

## Overview

The current MQTT relay configuration uses a public broker (emqx.io) with no authentication or encryption. This poses a security risk for distributed agent communication and creates a single point of failure. This track implements a self-hosted, secure MQTT infrastructure.

**Theme:** "Secure the messaging backbone"

---

## Tasks

### P16.6.1: Self-Hosted Mosquitto Broker

**Problem:** Public MQTT broker with no authentication. Token is empty in config.

**Solution:** Deploy Mosquitto MQTT broker via Docker Compose with:
- Persistent message storage
- Health checks
- Automatic restart
- Resource limits

**Files to modify:**
- `docker-compose.yml` — Add `mqtt` service with profile: `mqtt`
- `docker/mosquitto/mosquitto.conf` — Broker configuration
- `docker/mosquitto/passwd` — Authentication file (generated at startup)

**Acceptance Criteria:**
- [ ] Mosquitto service starts via `docker compose --profile mqtt up`
- [ ] Health check passes within 30s
- [ ] Messages persist across container restarts
- [ ] Resource limits: 256MB RAM, 0.5 CPU

---

### P16.6.2: TLS Encryption

**Problem:** MQTT traffic sent in plaintext over public internet.

**Solution:** Enable TLS 1.2+ for Mosquitto with:
- Self-signed certificates for local development
- Let's Encrypt support for production
- Automatic certificate rotation
- Configurable via `config.toml`

**Files to modify:**
- `docker/mosquitto/mosquitto.conf` — TLS listener configuration
- `docker/mosquitto/certs/` — Certificate directory
- `scripts/generate-certs.sh` — Certificate generation script
- `config.toml` — TLS configuration options

**Acceptance Criteria:**
- [ ] TLS listener on port 8883
- [ ] Self-signed certs generated automatically on first run
- [ ] Non-TLS listener (1883) disabled by default
- [ ] `config.toml` has `relay.tls_enabled`, `relay.ca_cert`, `relay.client_cert`, `relay.client_key`

---

### P16.6.3: Authentication

**Problem:** No authentication required for MQTT connections.

**Solution:** Username/password authentication with:
- Password file managed by Docker entrypoint
- Per-agent credentials generated at registration
- Credentials stored securely in blackboard (encrypted)

**Files to modify:**
- `docker/mosquitto/entrypoint.sh` — Password file generation
- `scripts/config-manager.sh` — Credential management
- `config.toml` — Auth configuration options

**Acceptance Criteria:**
- [ ] Anonymous connections disabled
- [ ] Username/password required for all connections
- [ ] Credentials generated automatically on first launch
- [ ] Credentials retrievable via `config-manager get mqtt.username/password`

---

### P16.6.4: Documentation

**Problem:** No documentation for secure MQTT deployment.

**Solution:** Comprehensive setup guide covering:
- Quick start (self-signed, local development)
- Production deployment (Let's Encrypt, reverse proxy)
- Troubleshooting common issues
- Migration from public broker

**Files to create:**
- `docs/mqtt-security-setup.md` — Setup and configuration guide

**Acceptance Criteria:**
- [ ] Quick start guide completes in < 10 minutes
- [ ] Production deployment documented
- [ ] Troubleshooting section covers 5+ common issues
- [ ] Migration guide from public broker included

---

## Dependencies

| Task | Depends On |
|------|-----------|
| P16.6.1 (Mosquitto) | None |
| P16.6.2 (TLS) | P16.6.1 |
| P16.6.3 (Auth) | P16.6.1 |
| P16.6.4 (Docs) | P16.6.1, P16.6.2, P16.6.3 |

**Recommended order:** P16.6.1 → P16.6.2 → P16.6.3 → P16.6.4

---

## Configuration Changes

### config.toml (new relay section)

```toml
[relay]
# Self-hosted broker (recommended)
url = "mqtts://localhost:8883"
enabled = true
tls_enabled = true
ca_cert = "./docker/mosquitto/certs/ca.crt"
client_cert = "./docker/mosquitto/certs/client.crt"
client_key = "./docker/mosquitto/certs/client.key"
username = ""  # Auto-generated on first launch
password = ""  # Auto-generated on first launch

# Legacy public broker (deprecated, remove after migration)
# url = "mqtts://broker.emqx.io:8883"
# id = "a8cc9080-4338-4678-825f-55bf5a5a861f"
# token = ""
```

### docker-compose.yml (new service)

```yaml
services:
  mqtt:
    image: eclipse-mosquitto:2.0
    profiles: ["mqtt"]
    container_name: ai-colab-mqtt
    ports:
      - "8883:8883"  # TLS
    volumes:
      - ./docker/mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro
      - ./docker/mosquitto/certs:/mosquitto/certs:ro
      - ./docker/mosquitto/passwd:/mosquitto/config/passwd:ro
      - mqtt-data:/mosquitto/data
    healthcheck:
      test: ["CMD", "mosquitto_sub", "-p", "8883", "-t", "$SYS/#", "-C", "1", "-W", "5"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
    restart: unless-stopped

volumes:
  mqtt-data:
```

---

## Testing Strategy

| Task | Test File | Test Type |
|------|-----------|-----------|
| P16.6.1 | `tests/test_mqtt_broker.sh` | Docker service health, persistence |
| P16.6.2 | `tests/test_mqtt_tls.sh` | TLS handshake, cert validation |
| P16.6.3 | `tests/test_mqtt_auth.sh` | Auth requirement, credential generation |

---

## Success Metrics

| Metric | Before | Target | Measurement |
|--------|--------|--------|-------------|
| MQTT Broker | Public (emqx.io) | Self-hosted | Docker Compose service |
| Encryption | None | TLS 1.2+ | TLS handshake verification |
| Authentication | None | Username/password | Auth rejection test |
| Single Point of Failure | Yes | No (local + recoverable) | Container restart test |
| Setup Time | N/A | < 10 minutes | `time docker compose --profile mqtt up` |

---

## Migration Plan

1. **Deploy self-hosted broker** alongside public broker (dual-write mode)
2. **Test connectivity** with self-hosted broker
3. **Switch primary relay** to self-hosted in `config.toml`
4. **Verify all agents** connect successfully
5. **Remove public broker** configuration after 7-day grace period

---

## Security Considerations

- Certificates stored outside container (volume mount)
- Password file owned by mosquitto user (read-only)
- No credentials logged or exposed in environment variables
- TLS certificates rotated every 90 days (Let's Encrypt)
- Firewall rules restrict MQTT port to local network only
