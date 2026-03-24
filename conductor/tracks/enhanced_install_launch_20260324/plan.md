# Track: Enhanced Installation & Launch Experience

**Created:** March 24, 2026  
**Priority:** High  
**Assigned:** @conductor, @all  
**Milestone:** Milestone 11

---

## 1. Objective

Transform ai-colab installation and launch into a user-friendly experience with two distinct pathways:

1. **Rich CLI/Console Setup** - Interactive terminal-based wizard with reconfiguration support
2. **Web UI Setup** - Browser-based configuration interface running in Docker container

Both pathways must support initial setup AND post-installation reconfiguration.

---

## 2. Success Criteria

- [ ] Users can complete installation via interactive CLI wizard
- [ ] Users can complete installation via Web UI (Docker-based)
- [ ] Users can reconfigure options post-installation via CLI (`./install.sh --reconfigure`)
- [ ] Users can reconfigure options post-installation via Web UI (`/settings`)
- [ ] All configuration changes are validated before application
- [ ] Configuration state is persisted and versioned
- [ ] Docker container includes Web UI by default
- [ ] Both pathways produce identical configuration output
- [ ] Migration from legacy config format supported

---

## 3. Implementation Plan

### Phase 1: Configuration Management Foundation
**Duration:** 2-3 days  
**Assigned:** @conductor

- [ ] **Task 1.1:** Create unified configuration schema (`config.schema.json`)
  - Define all configurable options (LLMs, modules, backends, preferences)
  - Add validation rules (types, ranges, required fields)
  - Support for environment-specific overrides
  
- [ ] **Task 1.2:** Implement configuration manager (`scripts/config-manager.sh`)
  - Read/write TOML, JSON, and ENV formats
  - Validate against schema
  - Support get/set/list/export operations
  - Atomic writes with rollback
  
- [ ] **Task 1.3:** Create configuration state tracker (`.ai-colab-state.json`)
  - Track installation status
  - Record configuration version
  - Log configuration changes
  - Support rollback to previous states

**Deliverables:**
- `config/config.schema.json`
- `scripts/config-manager.sh`
- `.ai-colab-state.json` (generated)

---

### Phase 2: Rich CLI Wizard
**Duration:** 3-4 days  
**Assigned:** @conductor, @gemini

- [ ] **Task 2.1:** Create interactive CLI installer (`scripts/install-wizard.sh`)
  - Step-by-step interactive prompts
  - Progress indicators
  - Input validation with helpful error messages
  - Preview before applying changes
  - Color-coded output
  
- [ ] **Task 2.2:** Implement reconfiguration mode (`install.sh --reconfigure`)
  - Load existing configuration
  - Show current values with option to change
  - Section-based reconfiguration (LLMs, modules, etc.)
  - Dry-run mode to preview changes
  
- [ ] **Task 2.3:** Add configuration profiles (`config/profiles/`)
  - Pre-defined profiles (minimal, standard, full)
  - Custom profile creation
  - Profile switching
  
- [ ] **Task 2.4:** Create CLI help system (`install.sh --help`, `install.sh --guide`)
  - Comprehensive help text
  - Examples for common scenarios
  - Troubleshooting guide

**Deliverables:**
- `scripts/install-wizard.sh`
- `install.sh --reconfigure` mode
- `config/profiles/*.toml`
- Enhanced help documentation

---

### Phase 3: Docker Container Setup
**Duration:** 2-3 days  
**Assigned:** @qwen, @deepseek

- [ ] **Task 3.1:** Create Dockerfile with Web UI dependencies
  - Base image (Ubuntu 22.04 or Alpine)
  - Python 3.10+ for Flask/FastAPI
  - Node.js for frontend (if needed)
  - tmux, hcom, and ai-colab dependencies
  - Volume mounts for persistence
  
- [ ] **Task 3.2:** Create Docker Compose configuration (`docker-compose.yml`)
  - Web UI service
  - Port mappings (8080:8080)
  - Volume mounts for config, modules, projects
  - Environment variable configuration
  - Health checks
  
- [ ] **Task 3.3:** Implement container entrypoint (`docker/entrypoint.sh`)
  - Check for first-run vs. existing install
  - Auto-start Web UI or CLI based on flags
  - Configuration validation on startup
  - Log rotation and management

**Deliverables:**
- `Dockerfile`
- `docker-compose.yml`
- `docker/entrypoint.sh`
- `.dockerignore`

---

### Phase 4: Web UI Backend
**Duration:** 4-5 days  
**Assigned:** @gemini, @claude

- [ ] **Task 4.1:** Create Flask/FastAPI backend (`webui/app.py`)
  - RESTful API endpoints
  - Configuration CRUD operations
  - Validation against schema
  - Authentication (optional, token-based)
  
- [ ] **Task 4.2:** Implement API endpoints
  - `GET /api/config` - Get current configuration
  - `PUT /api/config` - Update configuration
  - `GET /api/status` - System status
  - `POST /api/install` - Trigger installation
  - `POST /api/launch` - Launch agents/dashboard
  - `GET /api/logs` - Stream logs
  
- [ ] **Task 4.3:** Add WebSocket support for real-time updates
  - Live log streaming
  - Installation progress
  - Agent status updates
  - Configuration change notifications
  
- [ ] **Task 4.4:** Implement security measures
  - Input sanitization
  - Rate limiting
  - CORS configuration
  - Optional authentication

**Deliverables:**
- `webui/app.py`
- `webui/api/` (API routes)
- `webui/models/` (data models)
- `requirements-webui.txt`

---

### Phase 5: Web UI Frontend
**Duration:** 4-5 days  
**Assigned:** @gemini, @claude

- [ ] **Task 5.1:** Create responsive HTML/CSS/JS frontend
  - Modern, clean design
  - Mobile-responsive
  - Dark/light theme support
  - Accessible (WCAG 2.1 AA)
  
- [ ] **Task 5.2:** Implement setup wizard pages
  - Welcome screen
  - LLM selection & configuration
  - Module selection
  - Backend configuration
  - Review & apply
  
- [ ] **Task 5.3:** Create dashboard pages
  - System status overview
  - Agent management
  - Configuration editor
  - Log viewer
  - Settings
  
- [ ] **Task 5.4:** Add real-time features
  - Live status updates (WebSocket)
  - Progress indicators
  - Toast notifications
  - Auto-refresh

**Deliverables:**
- `webui/templates/*.html`
- `webui/static/css/*.css`
- `webui/static/js/*.js`
- `webui/static/img/` (assets)

---

### Phase 6: Integration & Testing
**Duration:** 3-4 days  
**Assigned:** @all

- [ ] **Task 6.1:** Integrate CLI and Web UI with config manager
  - Both pathways use same config schema
  - Consistent validation
  - Shared state tracking
  
- [ ] **Task 6.2:** Create comprehensive test suite
  - Unit tests for config manager
  - Integration tests for CLI wizard
  - E2E tests for Web UI
  - Docker container tests
  
- [ ] **Task 6.3:** Performance optimization
  - Web UI load time < 2s
  - Config changes applied < 5s
  - Docker startup < 30s
  
- [ ] **Task 6.4:** User acceptance testing
  - Test with new users (no prior config)
  - Test with existing users (migration)
  - Collect feedback and iterate

**Deliverables:**
- `tests/test_config_manager.sh`
- `tests/test_install_wizard.sh`
- `tests/webui/` (E2E tests)
- Test reports

---

### Phase 7: Documentation & Deployment
**Duration:** 2 days  
**Assigned:** @conductor

- [ ] **Task 7.1:** Create user documentation
  - Installation guide (CLI pathway)
  - Installation guide (Web UI pathway)
  - Reconfiguration guide
  - Troubleshooting guide
  
- [ ] **Task 7.2:** Create developer documentation
  - Configuration schema reference
  - API documentation
  - Docker deployment guide
  - Contributing guidelines
  
- [ ] **Task 7.3:** Update existing documentation
  - README.md with new installation options
  - Quick start guide
  - Migration guide from legacy setup

**Deliverables:**
- `docs/INSTALLATION.md`
- `docs/WEBUI_GUIDE.md`
- `docs/CONFIGURATION.md`
- Updated README.md

---

## 4. Technical Specifications

### 4.1 Configuration Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "installation": {
      "type": "object",
      "properties": {
        "status": { "type": "string", "enum": ["pending", "in-progress", "complete", "failed"] },
        "date": { "type": "string", "format": "date-time" },
        "pathway": { "type": "string", "enum": ["cli", "webui", "docker"] }
      }
    },
    "llms": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "enabled": { "type": "boolean" },
          "api_key_env": { "type": "string" },
          "model": { "type": "string" },
          "endpoint": { "type": "string", "format": "uri" }
        },
        "required": ["name", "enabled"]
      }
    },
    "modules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "enabled": { "type": "boolean" },
          "config": { "type": "object" }
        }
      }
    },
    "compute": {
      "type": "object",
      "properties": {
        "backend": { "type": "string", "enum": ["local", "nvidia", "runpod"] },
        "endpoint": { "type": "string" },
        "api_key_env": { "type": "string" }
      }
    },
    "preferences": {
      "type": "object",
      "properties": {
        "theme": { "type": "string", "enum": ["dark", "light", "auto"] },
        "auto_approve": { "type": "boolean" },
        "timeout": { "type": "integer", "minimum": 60, "maximum": 86400 }
      }
    }
  },
  "required": ["version", "installation"]
}
```

### 4.2 CLI Wizard Flow

```
┌─────────────────────────────────────────┐
│  Welcome to ai-colab Setup              │
│  ─────────────────────────────────────  │
│  This wizard will help you configure    │
│  your multi-agent development environment│
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Step 1: Select Installation Type       │
│  ─────────────────────────────────────  │
│  ○ Minimal (Core only)                  │
│  ● Standard (Recommended)               │
│  ○ Full (All features + modules)        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Step 2: Configure LLMs                 │
│  ─────────────────────────────────────  │
│  [✓] Gemini (gemini-cli)                │
│  [✓] Qwen (qwen-code)                   │
│  [ ] Claude (claude-code)               │
│  [ ] DeepSeek (deepseek-cli)            │
│  [✓] vLLM (local)                       │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Step 3: Configure Modules              │
│  ─────────────────────────────────────  │
│  [✓] atari-8bit (Atari 8-bit dev)       │
│  [ ] custom-module                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Step 4: Review & Apply                 │
│  ─────────────────────────────────────  │
│  LLMs: 3 enabled                        │
│  Modules: 1 enabled                     │
│  Backend: local                         │
│                                         │
│  Apply configuration? [Y/n]             │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Installation Complete! ✓               │
│  ─────────────────────────────────────  │
│  Next: ./launch.sh                      │
│  Reconfigure: ./install.sh --reconfigure│
└─────────────────────────────────────────┘
```

### 4.3 Web UI Architecture

```
┌─────────────────────────────────────────────────┐
│                   Web Browser                    │
│  ┌───────────────────────────────────────────┐  │
│  │              Web UI (React/Vanilla)        │  │
│  │  - Setup Wizard                            │  │
│  │  - Dashboard                               │  │
│  │  - Settings                                │  │
│  └───────────────────────────────────────────┘  │
│                      ↕ WebSocket/REST           │
└─────────────────────────────────────────────────┘
                      ↕ HTTP/WS (Port 8080)
┌─────────────────────────────────────────────────┐
│              Docker Container                    │
│  ┌───────────────────────────────────────────┐  │
│  │         Flask/FastAPI Backend              │  │
│  │  - /api/config                             │  │
│  │  - /api/install                            │  │
│  │  - /api/launch                             │  │
│  │  - /api/logs (WebSocket)                   │  │
│  └───────────────────────────────────────────┘  │
│                      ↕                          │
│  ┌───────────────────────────────────────────┐  │
│  │         Configuration Manager              │  │
│  │  - Validate against schema                 │  │
│  │  - Atomic writes                           │  │
│  │  - State tracking                          │  │
│  └───────────────────────────────────────────┘  │
│                      ↕                          │
│  ┌───────────────────────────────────────────┐  │
│  │         ai-colab Core                      │  │
│  │  - install.sh                              │  │
│  │  - launch.sh                               │  │
│  │  - modules/                                │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│  Volumes:                                       │
│  - /config → host:~/.ai-colab/config           │
│  - /modules → host:~/ai_colab/modules          │
│  - /projects → host:~/projects                 │
└─────────────────────────────────────────────────┘
```

### 4.4 Reconfiguration Flow

```bash
# CLI Reconfiguration
$ ./install.sh --reconfigure

Current Configuration:
  LLMs: gemini, qwen, vllm
  Modules: atari-8bit
  Backend: local

Select section to reconfigure:
  1) LLMs
  2) Modules
  3) Backend
  4) Preferences
  5) Exit

Choice [1-5]: 1

LLM Configuration:
  [✓] gemini (gemini-3.0)
  [✓] qwen (qwen3-next-80b-a3b-instruct)
  [✓] vllm (http://192.168.0.193:8000/v1)
  [ ] claude

Changes:
  - claude: Will be enabled

Apply changes? [Y/n]: y

✓ Configuration updated
✓ Restarting services...
✓ Done!
```

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Config Schema Changes** | Medium | High | Version schema, migration scripts |
| **Web UI Security** | Medium | High | Input validation, auth, rate limiting |
| **Docker Compatibility** | Low | Medium | Test on multiple platforms |
| **Performance Issues** | Low | Medium | Load testing, optimization |
| **User Confusion** | Low | Low | Clear documentation, wizards |

---

## 6. Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Config Foundation | 2-3 days | None |
| Phase 2: CLI Wizard | 3-4 days | Phase 1 |
| Phase 3: Docker Setup | 2-3 days | None |
| Phase 4: Web UI Backend | 4-5 days | Phase 1, 3 |
| Phase 5: Web UI Frontend | 4-5 days | Phase 4 |
| Phase 6: Integration & Test | 3-4 days | All phases |
| Phase 7: Documentation | 2 days | All phases |
| **Total** | **20-26 days** | |

---

## 7. Acceptance Criteria

### CLI Pathway
- [ ] User can complete installation in < 5 minutes
- [ ] All configuration options accessible via wizard
- [ ] Reconfiguration preserves existing settings
- [ ] Dry-run mode shows changes before applying
- [ ] Help system provides clear guidance

### Web UI Pathway
- [ ] Web UI accessible at http://localhost:8080
- [ ] Setup wizard completes in < 10 steps
- [ ] Real-time status updates work
- [ ] Configuration changes apply without restart
- [ ] Mobile-responsive design

### Docker
- [ ] Container starts in < 30 seconds
- [ ] Configuration persists across restarts
- [ ] Logs accessible via docker logs and Web UI
- [ ] Volume mounts work correctly

### General
- [ ] Both pathways produce identical config
- [ ] Migration from legacy config works
- [ ] All tests pass (>90% coverage)
- [ ] Documentation complete

---

**Track Status:** ⚪ Planning  
**Next Action:** Begin Phase 1 implementation
