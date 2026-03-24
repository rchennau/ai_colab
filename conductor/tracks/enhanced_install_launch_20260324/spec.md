# Specification: Enhanced Installation & Launch Experience

## 1. Overview

Provide users with two distinct installation and launch pathways:
1. **Rich CLI Wizard** - Interactive terminal-based setup with reconfiguration
2. **Web UI** - Browser-based interface running in Docker container

Both pathways must support initial setup AND post-installation reconfiguration.

---

## 2. User Stories

### CLI Pathway

**US-1: First-Time Installation**
> As a new user, I want an interactive CLI wizard that guides me through installation so that I can set up ai-colab correctly without reading extensive documentation.

**Acceptance Criteria:**
- Wizard presents options in logical order
- Default values provided for all options
- Validation with helpful error messages
- Preview of changes before applying
- Completion summary with next steps

**US-2: Reconfiguration**
> As an existing user, I want to reconfigure ai-colab options without reinstalling so that I can adapt the setup to my changing needs.

**Acceptance Criteria:**
- `./install.sh --reconfigure` command available
- Shows current configuration values
- Allows section-by-section reconfiguration
- Dry-run mode to preview changes
- Rollback capability if issues occur

**US-3: Configuration Profiles**
> As a power user, I want to save and switch between configuration profiles so that I can quickly adapt ai-colab for different projects.

**Acceptance Criteria:**
- Create custom profiles
- Switch between profiles
- Export/import profiles
- Pre-defined profiles (minimal, standard, full)

### Web UI Pathway

**US-4: Docker-Based Setup**
> As a user who prefers GUIs, I want to run ai-colab in Docker with a Web UI so that I can configure everything through my browser.

**Acceptance Criteria:**
- Single docker-compose up command
- Web UI accessible at localhost:8080
- Setup wizard in browser
- Real-time status updates

**US-5: Web-Based Management**
> As a user, I want to manage ai-colab through the Web UI so that I don't need to use the command line.

**Acceptance Criteria:**
- Dashboard showing system status
- Agent management (start/stop/restart)
- Configuration editor with validation
- Log viewer with filtering
- Settings page

---

## 3. Functional Requirements

### FR-1: Configuration Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Unified configuration schema (JSON Schema) | Must |
| FR-1.2 | Support TOML, JSON, ENV formats | Must |
| FR-1.3 | Validation against schema | Must |
| FR-1.4 | Atomic writes with rollback | Must |
| FR-1.5 | Configuration versioning | Should |
| FR-1.6 | Environment-specific overrides | Could |

### FR-2: CLI Wizard

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Interactive step-by-step wizard | Must |
| FR-2.2 | Progress indicators | Must |
| FR-2.3 | Input validation | Must |
| FR-2.4 | Preview before applying | Must |
| FR-2.5 | Color-coded output | Should |
| FR-2.6 | Help system (--help, --guide) | Should |

### FR-3: Reconfiguration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | `--reconfigure` flag support | Must |
| FR-3.2 | Show current values | Must |
| FR-3.3 | Section-based editing | Must |
| FR-3.4 | Dry-run mode | Must |
| FR-3.5 | Rollback capability | Should |

### FR-4: Docker Support

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Dockerfile with all dependencies | Must |
| FR-4.2 | docker-compose.yml | Must |
| FR-4.3 | Volume mounts for persistence | Must |
| FR-4.4 | Health checks | Should |
| FR-4.5 | Multi-architecture support | Could |

### FR-5: Web UI Backend

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | RESTful API (Flask/FastAPI) | Must |
| FR-5.2 | Configuration CRUD endpoints | Must |
| FR-5.3 | WebSocket for real-time updates | Must |
| FR-5.4 | Authentication (optional) | Should |
| FR-5.5 | Rate limiting | Should |

### FR-6: Web UI Frontend

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-6.1 | Responsive design | Must |
| FR-6.2 | Setup wizard pages | Must |
| FR-6.3 | Dashboard page | Must |
| FR-6.4 | Configuration editor | Must |
| FR-6.5 | Log viewer | Should |
| FR-6.6 | Dark/light theme | Should |
| FR-6.7 | Mobile-responsive | Should |

---

## 4. Non-Functional Requirements

### NFR-1: Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| CLI wizard completion | < 5 minutes | User testing |
| Web UI load time | < 2 seconds | Lighthouse |
| Config change application | < 5 seconds | Timing tests |
| Docker startup | < 30 seconds | docker-compose up timing |

### NFR-2: Security

- All user input validated and sanitized
- Optional authentication for Web UI
- Rate limiting on API endpoints
- CORS properly configured
- No secrets in logs

### NFR-3: Usability

- WCAG 2.1 AA compliance for Web UI
- Clear error messages with resolution steps
- Consistent UI/UX across CLI and Web UI
- Comprehensive help documentation

### NFR-4: Compatibility

- macOS (iTerm2, Terminal.app)
- Linux (Ubuntu 22.04+, WSL2)
- Docker Desktop (macOS, Windows, Linux)
- Modern browsers (Chrome, Firefox, Safari, Edge)

---

## 5. Data Model

### Configuration Object

```typescript
interface AiColabConfig {
  version: string;  // Semantic version (e.g., "2.4.0")
  
  installation: {
    status: 'pending' | 'in-progress' | 'complete' | 'failed';
    date?: string;  // ISO 8601
    pathway: 'cli' | 'webui' | 'docker';
    version: string;  // ai-colab version
  };
  
  llms: LLMConfig[];
  modules: ModuleConfig[];
  compute: ComputeConfig;
  preferences: PreferencesConfig;
}

interface LLMConfig {
  name: string;  // e.g., "gemini", "qwen"
  enabled: boolean;
  api_key_env?: string;  // Environment variable name
  model?: string;  // e.g., "gemini-3.0"
  endpoint?: string;  // Custom endpoint URL
}

interface ModuleConfig {
  id: string;  // e.g., "atari-8bit"
  enabled: boolean;
  config?: Record<string, any>;  // Module-specific config
}

interface ComputeConfig {
  backend: 'local' | 'nvidia' | 'runpod';
  endpoint?: string;
  api_key_env?: string;
}

interface PreferencesConfig {
  theme: 'dark' | 'light' | 'auto';
  auto_approve: boolean;
  timeout: number;  // seconds (60-86400)
}
```

### Configuration State

```typescript
interface ConfigState {
  current_version: string;
  previous_versions: ConfigVersion[];
  change_log: ChangeEntry[];
}

interface ConfigVersion {
  version: string;
  timestamp: string;
  config_snapshot: AiColabConfig;
}

interface ChangeEntry {
  timestamp: string;
  pathway: 'cli' | 'webui';
  changes: string[];  // Human-readable descriptions
  config_before: string;  // Path to snapshot
  config_after: string;  // Path to snapshot
}
```

---

## 6. API Specification

### REST Endpoints

```yaml
openapi: 3.0.0
info:
  title: ai-colab Configuration API
  version: 1.0.0

paths:
  /api/config:
    get:
      summary: Get current configuration
      responses:
        200:
          description: Configuration object
    put:
      summary: Update configuration
      requestBody:
        content:
          application/json:
            schema: AiColabConfig
      responses:
        200:
          description: Configuration updated
        400:
          description: Validation failed

  /api/status:
    get:
      summary: Get system status
      responses:
        200:
          description: Status object

  /api/install:
    post:
      summary: Trigger installation
      requestBody:
        content:
          application/json:
            schema: InstallRequest
      responses:
        202:
          description: Installation started

  /api/launch:
    post:
      summary: Launch agents/dashboard
      requestBody:
        content:
          application/json:
            schema: LaunchRequest
      responses:
        202:
          description: Launch started

  /api/logs:
    get:
      summary: Get logs
      parameters:
        - name: lines
          in: query
          schema:
            type: integer
            default: 100
      responses:
        200:
          description: Log lines
```

### WebSocket Events

```typescript
// Client → Server
interface ClientEvents {
  'subscribe:logs': { filter?: string };
  'subscribe:status': void;
  'config:change': Partial<AiColabConfig>;
}

// Server → Client
interface ServerEvents {
  'log:entry': {
    timestamp: string;
    level: 'info' | 'warn' | 'error';
    message: string;
  };
  'status:update': SystemStatus;
  'config:changed': {
    timestamp: string;
    changes: string[];
  };
  'install:progress': {
    step: string;
    progress: number;  // 0-100
    message: string;
  };
}
```

---

## 7. UI Mockups

### CLI Wizard

See Phase 2 specification in plan.md for ASCII mockups.

### Web UI - Setup Wizard

```
┌────────────────────────────────────────────────────────────┐
│  ai-colab Setup                              [1/5] Basic   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Welcome to ai-colab!                                      │
│                                                            │
│  This wizard will help you set up your multi-agent         │
│  development environment.                                  │
│                                                            │
│  Estimated time: 5 minutes                                 │
│                                                            │
│  What would you like to configure?                         │
│                                                            │
│  ○ Quick Setup (Recommended)                               │
│    Pre-configured with sensible defaults                   │
│                                                            │
│  ● Custom Setup                                            │
│    Configure all options step-by-step                      │
│                                                            │
│  ○ Advanced                                                │
│    Direct configuration editor                             │
│                                                            │
│                    [Cancel]          [Next →]              │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Web UI - Dashboard

```
┌────────────────────────────────────────────────────────────┐
│  ai-colab Dashboard                                        │
├────────────────────────────────────────────────────────────┤
│  [Overview] [Agents] [Configuration] [Logs] [Settings]     │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  System Status: ● Online                                   │
│                                                            │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │ Active Agents   │  │ Configuration   │                 │
│  │                 │  │                 │                 │
│  │ ● gemini        │  │ Version: 2.4.0  │                 │
│  │ ● qwen          │  │ Pathway: docker │                 │
│  │ ○ claude        │  │ Last: 2026-03-24│                 │
│  │ ● vllm          │  │                 │                 │
│  └─────────────────┘  └─────────────────┘                 │
│                                                            │
│  Recent Activity                                           │
│  ─────────────────────────────────────────────────────     │
│  12:05  Agent qwen started                                 │
│  12:03  Configuration updated                             │
│  12:00  System started                                    │
│                                                            │
│  Quick Actions                                             │
│  ─────────────────────────────────────────────────────     │
│  [Restart All] [View Logs] [Reconfigure] [Stop All]       │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 8. Testing Strategy

### Unit Tests
- Configuration schema validation
- Config manager operations (get/set/list)
- Input validation
- Atomic writes

### Integration Tests
- CLI wizard end-to-end
- Web UI API integration
- Docker container startup
- Configuration persistence

### E2E Tests
- Full installation flow (CLI)
- Full installation flow (Web UI)
- Reconfiguration flow
- Migration from legacy config

### Performance Tests
- Web UI load time
- Config change latency
- Docker startup time
- Concurrent user handling

---

## 9. Deployment

### Docker Deployment

```bash
# Quick start
docker-compose up -d

# Access Web UI
open http://localhost:8080

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Native Installation

```bash
# Quick install
./install.sh --auto

# Interactive install
./install.sh --wizard

# Reconfigure
./install.sh --reconfigure
```

---

**Status:** ⚪ Draft  
**Last Updated:** March 24, 2026
