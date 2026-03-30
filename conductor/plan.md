# Milestone 17: WebUI Engineering & UX Overhaul

**Objective:** Transform the monolithic Web UI backend into a modular architecture (v3.0) and redesign the frontend navigation for a simplified, professional user experience.

---

## 📋 Background & Motivation

The current Web UI (v2.2) has grown into a monolithic `app.py` that is difficult to maintain. The frontend navigation has multiple orphaned pages and inconsistent submenu patterns. Milestone 17 aims to consolidate these into a streamlined "3-menu" architecture and refactor the backend into modular blueprints.

---

## 🏗️ Proposed Solution

### 1. Frontend: 3-Menu Navigation Architecture
Consolidate all existing and orphaned pages into three primary navigation pillars:
1.  **Dashboard**: The central hub for project overview and knowledge.
2.  **Collaboration**: Agent management, fleet control, and interactive terminals.
3.  **System**: Infrastructure monitoring, configuration, setup, and logs.

### 2. Backend: Modular Blueprint Architecture (v3.0)
*   Finalize the migration from `app.py` to `app_refactored.py`.
*   Implement a new `Terminal` blueprint for PTY management.
*   Move remaining logic (Config, Profiles, Modules) into appropriate blueprints.
*   Ensure full parity with the monolithic `app.py` before switching.

---

## 🛠️ Implementation Plan

### Phase 1: Modular Backend (v3.0)
1.  **Create `webui/api/terminal.py`**:
    *   Migrate `PTYManager` from `app.py`.
    *   Implement `/api/terminal/spawn`, `/api/terminal/list`, `/api/terminal/close`.
    *   Handle Socket.IO events for terminal input/output/resize.
2.  **Enhance `webui/api/system.py`**:
    *   Ensure all health, preflight, and metrics endpoints are fully implemented.
    *   Add `/api/shutdown` and `/api/session/*` endpoints.
3.  **Update `webui/app_refactored.py`**:
    *   Register the new terminal blueprint.
    *   Ensure Socket.IO is correctly integrated with the PTY manager.
    *   Fix import paths to avoid monolithic `app.py` dependency.

### Phase 2: Frontend UX Overhaul
1.  **Consolidate Navigation in `webui/index.html`**:
    *   Update `nav` to strictly show 3 buttons.
    *   Reorganize all `page` divs into sub-pages of the 3 main menus.
2.  **Integrate Knowledge Base**:
    *   Move detailed Knowledge Base search into a sub-tab of Dashboard.
    *   Ensure real-time KB stats are visible on the main Dashboard overview.
3.  **Unified System Monitoring**:
    *   Merge Observability, Health, and Logs into a unified "Monitoring" sub-page under System.
    *   Implement "Quick Actions" panel for common maintenance tasks.

### Phase 3: Final Switch & Validation
1.  **Update `launch.sh`**: Point to `webui/app_refactored.py`.
2.  **Verify End-to-End**:
    *   Test agent spawning and terminal interaction.
    *   Verify configuration saving/loading.
    *   Test real-time status updates via WebSocket.

---

## ✅ Verification & Testing

### Automated Tests
- Run `tests/test_webui.sh` to verify API availability.
- Use `scripts/test-webui-api.sh` for endpoint validation.

### Manual Verification
1.  Launch Web UI: `./launch.sh` -> Select choice 2.
2.  Verify Navigation: Click through all 3 menus and their sub-tabs.
3.  Verify Terminal: Spawn a Conductor terminal and send `!status`.
4.  Verify Config: Change a setting and ensure it persists after refresh.
