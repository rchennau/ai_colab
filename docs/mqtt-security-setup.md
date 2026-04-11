# MQTT Security Setup Guide

**Version:** 1.0  
**Date:** 2026-04-10  
**Related:** Phase 16.6 — Foundation Hardening: MQTT Security  

---

## Overview

This guide covers the setup of a self-hosted, secure MQTT broker for ai-colab's distributed agent communication. The broker provides:

- **TLS 1.2+ encryption** for all MQTT traffic
- **Username/password authentication** for all connections
- **Persistent message storage** across container restarts
- **Resource-limited deployment** (256MB RAM, 0.5 CPU)

---

## Quick Start (Local Development)

### Prerequisites

- Docker and Docker Compose installed
- OpenSSL installed (for certificate generation)
- ai-colab project cloned

### Step 1: Generate TLS Certificates

```bash
# Generate self-signed certificates (output: docker/mosquitto/certs/)
bash scripts/generate-certs.sh
```

This creates:
- `docker/mosquitto/certs/ca.crt` — CA certificate (distribute to clients)
- `docker/mosquitto/certs/ca.key` — CA private key (keep secret)
- `docker/mosquitto/certs/server.crt` — Server certificate
- `docker/mosquitto/certs/server.key` — Server private key (keep secret)

### Step 2: Start the MQTT Broker

```bash
# Start MQTT broker (first run generates credentials)
docker compose --profile mqtt up -d

# Check status
docker compose --profile mqtt ps

# View logs (includes generated credentials on first run)
docker compose --profile mqtt logs mqtt
```

On first run, the broker generates random admin credentials and prints them to the logs:

```
============================================
  MQTT Broker Credentials (First Run)
============================================
  Username: ai-colab-admin
  Password: <random-password>
============================================
```

**Save these credentials immediately!** They are required for all MQTT client connections.

### Step 3: Verify Broker is Running

```bash
# Check health status
docker compose --profile mqtt ps

# Should show:
# ai-colab-mqtt   eclipse-mosquitto:2.0   Up (healthy)
```

### Step 4: Test MQTT Connection

```bash
# Subscribe to test topic (replace PASSWORD with your generated password)
docker exec ai-colab-mqtt mosquitto_sub \
  -h localhost \
  -p 8883 \
  -t "test/topic" \
  --cafile /mosquitto/certs/ca.crt \
  -u ai-colab-admin \
  -P <PASSWORD>

# In another terminal, publish a message
docker exec ai-colab-mqtt mosquitto_pub \
  -h localhost \
  -p 8883 \
  -t "test/topic" \
  -m "Hello from ai-colab!" \
  --cafile /mosquitto/certs/ca.crt \
  -u ai-colab-admin \
  -P <PASSWORD>
```

### Step 5: Update ai-colab Configuration

Update `config.toml` with your generated credentials:

```toml
[relay]
url = "mqtts://localhost:8883"
enabled = true
tls_enabled = true
ca_cert = "./docker/mosquitto/certs/ca.crt"
username = "ai-colab-admin"
password = "<your-generated-password>"
```

### Step 6: Restart ai-colab

```bash
# Restart to pick up new MQTT configuration
./launch.sh
```

---

## Production Deployment

### Using Let's Encrypt Certificates

For production, replace self-signed certificates with Let's Encrypt:

```bash
# Install certbot
sudo apt-get install certbot  # Debian/Ubuntu
# or
brew install certbot  # macOS

# Request certificate (replace with your domain)
sudo certbot certonly --standalone -d mqtt.yourdomain.com

# Copy certificates to Mosquitto directory
sudo cp /etc/letsencrypt/live/mqtt.yourdomain.com/fullchain.pem \
  docker/mosquitto/certs/server.crt
sudo cp /etc/letsencrypt/live/mqtt.yourdomain.com/privkey.pem \
  docker/mosquitto/certs/server.key
sudo cp /etc/letsencrypt/live/mqtt.yourdomain.com/chain.pem \
  docker/mosquitto/certs/ca.crt

# Set permissions
chmod 644 docker/mosquitto/certs/server.crt docker/mosquitto/certs/ca.crt
chmod 600 docker/mosquitto/certs/server.key
```

### Certificate Auto-Renewal

Add a cron job for automatic renewal:

```bash
# Edit crontab
crontab -e

# Add renewal job (runs daily at 3am)
0 3 * * * certbot renew --quiet && docker compose --profile mqtt restart mqtt
```

### Firewall Configuration

Restrict MQTT port to local network only:

```bash
# Allow MQTT from local network only
sudo ufw allow from 192.168.1.0/24 to any port 8883 proto tcp

# Or with iptables
sudo iptables -A INPUT -p tcp --dport 8883 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8883 -j DROP
```

---

## Migration from Public Broker

### Step 1: Deploy Self-Hosted Broker

Follow the Quick Start guide above to deploy the self-hosted broker alongside the public broker.

### Step 2: Test with Self-Hosted Broker

Update `config.toml` to use the self-hosted broker:

```toml
[relay]
url = "mqtts://localhost:8883"
enabled = true
# ... rest of config
```

### Step 3: Verify All Agents Connect

```bash
# Check agent connections via hcom
hcom list --names

# Check MQTT broker logs for connections
docker compose --profile mqtt logs mqtt
```

### Step 4: Monitor for 7 Days

Keep the public broker configuration commented but available in `config.toml`:

```toml
# Legacy public broker (available for rollback)
# url = "mqtts://broker.emqx.io:8883"
```

### Step 5: Remove Public Broker Configuration

After 7 days of stable operation, remove the commented public broker configuration.

---

## Troubleshooting

### Issue: Broker won't start

**Symptoms:** `docker compose ps` shows `Exit` or `Restarting`

**Solutions:**

1. **Check logs:**
   ```bash
   docker compose --profile mqtt logs mqtt
   ```

2. **Certificate issues:**
   ```bash
   # Verify certificates exist and are valid
   openssl x509 -in docker/mosquitto/certs/server.crt -noout -dates
   openssl rsa -in docker/mosquitto/certs/server.key -check
   ```

3. **Permission issues:**
   ```bash
   # Fix certificate permissions
   chmod 644 docker/mosquitto/certs/*.crt
   chmod 600 docker/mosquitto/certs/*.key
   ```

4. **Port conflict:**
   ```bash
   # Check if port 8883 is in use
   lsof -i :8883
   # or
   netstat -tlnp | grep 8883
   ```

### Issue: Clients can't connect

**Symptoms:** MQTT connection timeout or "connection refused"

**Solutions:**

1. **Verify TLS is enabled:**
   ```bash
   # Test TLS connection
   openssl s_client -connect localhost:8883 -CAfile docker/mosquitto/certs/ca.crt
   ```

2. **Verify credentials:**
   ```bash
   # Test authentication
   mosquitto_sub -h localhost -p 8883 -t "test" \
     --cafile docker/mosquitto/certs/ca.crt \
     -u ai-colab-admin -P <password>
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status
   # Ensure port 8883 is allowed
   ```

### Issue: Certificate expired

**Symptoms:** "certificate verify failed" errors

**Solutions:**

1. **Regenerate self-signed certificates:**
   ```bash
   bash scripts/generate-certs.sh
   docker compose --profile mqtt restart mqtt
   ```

2. **Renew Let's Encrypt certificates:**
   ```bash
   sudo certbot renew
   docker compose --profile mqtt restart mqtt
   ```

### Issue: Messages not persisting

**Symptoms:** Messages lost after container restart

**Solutions:**

1. **Verify volume mount:**
   ```bash
   docker inspect ai-colab-mqtt | grep -A5 Mounts
   ```

2. **Check persistence config:**
   ```bash
   # Should show: persistence true
   grep persistence docker/mosquitto/mosquitto.conf
   ```

### Issue: High memory usage

**Symptoms:** Container using > 256MB RAM

**Solutions:**

1. **Check queued messages:**
   ```bash
   # Mosquitto queues messages for disconnected clients
   # Clear old sessions
   docker exec ai-colab-mqtt mosquitto_sub -h localhost -p 8883 \
     --cafile /mosquitto/certs/ca.crt \
     -u ai-colab-admin -P <password> \
     -t '$SYS/broker/clients/disconnected'
   ```

2. **Adjust resource limits in docker-compose.yml:**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 512M  # Increase if needed
   ```

---

## Security Best Practices

1. **Never commit credentials** — Add `docker/mosquitto/passwd` to `.gitignore`
2. **Rotate passwords regularly** — Regenerate with `mosquitto_passwd`
3. **Use separate credentials per agent** — Create unique usernames for each LLM CLI
4. **Monitor broker logs** — Watch for failed authentication attempts
5. **Restrict network access** — Use firewall rules to limit broker access
6. **Rotate TLS certificates** — Auto-renewal for Let's Encrypt, annual for self-signed

---

## Configuration Reference

### config.toml Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `relay.url` | string | `mqtts://localhost:8883` | MQTT broker URL |
| `relay.enabled` | bool | `true` | Enable MQTT relay |
| `relay.tls_enabled` | bool | `true` | Require TLS |
| `relay.ca_cert` | string | `./docker/mosquitto/certs/ca.crt` | CA certificate path |
| `relay.client_cert` | string | `""` | Client certificate path (optional) |
| `relay.client_key` | string | `""` | Client key path (optional) |
| `relay.username` | string | `""` | MQTT username |
| `relay.password` | string | `""` | MQTT password |

### Docker Compose Profiles

| Profile | Service | Description |
|---------|---------|-------------|
| `mqtt` | `ai-colab-mqtt` | Self-hosted MQTT broker |
| `vllm` | `ai-colab-vllm` | Local vLLM model serving |
| `scaling` | `ai-colab-redis` | Redis caching layer |

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 8883 | TLS | MQTT secure listener |
| 1883 | — | Non-TLS listener (disabled by default) |

---

## Related Documentation

- [Phase 16.6 Specification](../conductor/tracks/mqtt_security_20260410/spec.md)
- [Phase 16.6 Implementation Plan](../conductor/tracks/mqtt_security_20260410/plan.md)
- [Mosquitto Configuration Reference](https://mosquitto.org/man/mosquitto-conf-5.html)
- [TLS Certificate Best Practices](https://letsencrypt.org/docs/best-practices/)
