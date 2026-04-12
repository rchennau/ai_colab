# ai-colab Docker Deployment Guide

Deploy ai-colab anywhere Docker runs — AWS, GCP, Azure, bare metal, or Kubernetes — using the same Docker Compose stack.

---

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose v2
- 4+ GB RAM (8+ GB recommended)
- 2+ CPU cores (4+ recommended)

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab

# Create environment file
cp .env.example .env

# Edit .env and add your API keys
nano .env  # or your preferred editor
```

### 2. Deploy

```bash
# Start core services (Web UI, API, MQTT broker)
docker compose up -d

# Start with agents (Gemini, Qwen, Claude, DeepSeek)
docker compose --profile agents up -d

# View logs
docker compose logs -f

# Check status
docker compose ps
```

### 3. Access

- **Web UI:** http://localhost:8080
- **API:** http://localhost:8081
- **MQTT Broker:** localhost:8883 (TLS)

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Docker Host                        │
│                                                       │
│  ┌──────────┐    ┌──────────┐    ┌─────────────────┐ │
│  │   Hub    │◄──►│   MQTT   │◄──►│  Agent: Gemini  │ │
│  │(Web+API) │    │ Broker   │    │  Agent: Qwen    │ │
│  │:8080/8081│    │  :8883   │    │  Agent: Claude  │ │
│  └──────────┘    └──────────┘    │  Agent: DeepSeek│ │
│                                   └─────────────────┘ │
│                                                       │
│  Shared Volumes: config, state, logs, hcom-data       │
└─────────────────────────────────────────────────────┘
```

### Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Hub | `ai-colab-hub` | 8080, 8081 | Web UI + API |
| MQTT | `ai-colab-mqtt` | 8883 | Secure messaging |
| Agent: Gemini | `ai-colab-agent-gemini` | — | Architect & Orchestrator |
| Agent: Qwen | `ai-colab-agent-qwen` | — | Assembly & Hardware |
| Agent: Claude | `ai-colab-agent-claude` | — | Generalist & Docs |
| Agent: DeepSeek | `ai-colab-agent-deepseek` | — | Logic & Optimization |
| Conductor | `ai-colab-conductor` | — | Orchestration (optional) |

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone |
| `COMPUTE_BACKEND` | `local` | Compute backend (local, nvidia, runpod) |
| `CONDUCTOR_INTERVAL` | `60` | Conductor loop interval (seconds) |
| `MQTT_USERNAME` | `ai-colab-admin` | MQTT broker username |
| `MQTT_PASSWORD` | _(auto-generated)_ | MQTT broker password |
| `GEMINI_API_KEY` | — | Google Gemini API key |
| `ANTHROPIC_API_KEY` | — | Anthropic Claude API key |
| `OPENAI_API_KEY` | — | OpenAI API key |
| `DEEPSEEK_API_KEY` | — | DeepSeek API key |
| `QWEN_API_KEY` | — | Qwen API key |
| `NVIDIA_API_KEY` | — | NVIDIA NIM API key |

### Persistent Volumes

| Volume | Purpose |
|--------|---------|
| `ai-colab-config` | Configuration files |
| `ai-colab-state` | Project state |
| `ai-colab-prefs` | User preferences |
| `ai-colab-env` | Environment variables |
| `ai-colab-logs` | Service logs |
| `hcom-data` | hcom messaging data |
| `mqtt-data` | MQTT message persistence |
| `mqtt-certs` | TLS certificates |

---

## Deployment Profiles

### Core Only (Default)

```bash
docker compose up -d
```

Starts: Hub + MQTT Broker

### With Agents

```bash
docker compose --profile agents up -d
```

Starts: Hub + MQTT + All Agents (Gemini, Qwen, Claude, DeepSeek)

### With Conductor

```bash
docker compose --profile agents up -d conductor
```

Starts: Hub + MQTT + Agents + Conductor

### Selective Agents

```bash
# Start only specific agents
docker compose up -d agent-gemini agent-qwen
```

---

## Production Deployment

### 1. Secure MQTT Password

```bash
# Generate a strong password
MQTT_PASSWORD=$(openssl rand -base64 32)

# Add to .env
echo "MQTT_PASSWORD=$MQTT_PASSWORD" >> .env
```

### 2. Set API Keys

```bash
# Add your API keys to .env
echo "GEMINI_API_KEY=your-key" >> .env
echo "ANTHROPIC_API_KEY=your-key" >> .env
```

### 3. Deploy

```bash
docker compose --profile agents up -d
```

### 4. Verify

```bash
# Check all services are healthy
docker compose ps

# Check Web UI
curl http://localhost:8080/health

# Check MQTT
docker exec ai-colab-mqtt mosquitto_sub -h localhost -p 8883 -t 'test' -C 1 -W 5
```

---

## Cloud Deployment

### AWS EC2

```bash
# Launch Ubuntu 22.04 instance
# SSH into instance
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker

# Clone and deploy
git clone https://github.com/ai-colab/ai-colab.git
cd ai-colab
cp .env.example .env
# Edit .env with your API keys
docker compose --profile agents up -d
```

### GCP Compute Engine

```bash
# Create VM with Docker image or install manually
gcloud compute instances create ai-colab \
    --image-family ubuntu-2204-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-4 \
    --scopes cloud-platform

# SSH and deploy as above
```

### Azure VM

```bash
# Create Ubuntu VM
az vm create \
    --resource-group ai-colab \
    --name ai-colab-vm \
    --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
    --size Standard_B4ms

# SSH and deploy as above
```

### Any Docker Host

The same `docker compose up -d` works on:
- Bare metal servers
- Kubernetes (via Kompose or Docker Compose on K8s)
- Raspberry Pi 4 (arm64, with reduced resources)
- Any cloud VM with Docker installed

---

## Troubleshooting

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f hub
docker compose logs -f mqtt
docker compose logs -f agent-gemini
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart hub

# Recreate service
docker compose up -d --force-recreate hub
```

### Check Health

```bash
# Check all service health
docker compose ps

# Check individual service
docker inspect ai-colab-hub --format='{{.State.Health.Status}}'
```

### Common Issues

**MQTT broker not starting:**
```bash
docker compose logs mqtt
# Check if port 8883 is in use
sudo lsof -i :8883
```

**Agents not connecting:**
```bash
# Check agent logs
docker compose logs agent-gemini

# Verify MQTT connectivity
docker exec ai-colab-agent-gemini bash -c "
    mosquitto_sub -h mqtt -p 8883 -t 'test' -C 1 -W 5
"
```

**Web UI not accessible:**
```bash
# Check hub health
docker compose ps hub
docker compose logs hub

# Verify port binding
docker port ai-colab-hub
```

### Clean Reset

```bash
# Stop and remove all containers
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v

# Rebuild images
docker compose build --no-cache

# Start fresh
docker compose up -d
```

---

## Resource Requirements

| Deployment | CPU | RAM | Disk |
|------------|-----|-----|------|
| Core only (Hub + MQTT) | 2 cores | 4 GB | 10 GB |
| + 1 Agent | 4 cores | 6 GB | 15 GB |
| + All Agents | 8 cores | 12 GB | 25 GB |
| + Conductor | 10 cores | 14 GB | 30 GB |

---

## Security

- MQTT broker uses TLS 1.2+ encryption
- All API keys stored in environment variables (not in images)
- Non-root user in containers
- Volume permissions set correctly
- No secrets committed to git (use .env file)

### Best Practices

1. **Never commit `.env`** — Add to `.gitignore`
2. **Use strong MQTT password** — Generate with `openssl rand -base64 32`
3. **Rotate API keys regularly** — Update `.env` and restart
4. **Monitor logs** — `docker compose logs -f`
5. **Update regularly** — `git pull && docker compose build && docker compose up -d`

---

## Related Documentation

- [Phase 16.6: MQTT Security Setup](./mqtt-security-setup.md)
- [Installation Guide](./INSTALLATION.md)
- [Python Environment Setup](../PYTHON_ENV_SETUP.md)
