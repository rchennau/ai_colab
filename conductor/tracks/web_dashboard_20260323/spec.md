# Track: Visual Health Web Overlay

## 1. Objective
Create a high-resolution web-based dashboard to visualize long-term project health, performance trends, and multi-agent coordination metrics.

## 2. Specification

### 2.1 Backend (Python/Flask)
- A lightweight web server that interfaces with `hcom.db`.
- **API Endpoints**:
  - `/api/performance`: Returns cycle counts for all routines over time (JSON).
  - `/api/tracks`: Returns current track status and completion velocity.
  - `/api/events`: Returns recent `hcom` event distribution (who is talking to whom).

### 2.2 Frontend (HTML/JS/Chart.js)
- A responsive single-page dashboard.
- **Visuals**:
  - **Performance Graph**: Multi-line chart showing cycle counts across commits.
  - **Progress Gauges**: Visual milestones completion.
  - **Activity Heatmap**: Showing which agents are most active.

### 2.3 Integration
- **Command**: `!web-start` (starts the server) and `!web-stop`.
- The Conductor Dashboard TUI should display the server URL (e.g., `http://localhost:5050`) when active.

## 3. Success Criteria
- [ ] Web server starts and serves data from the blackboard.
- [ ] Performance trends are clearly visible via Chart.js.
- [ ] Multiple agents' contributions are tracked and visualized.
