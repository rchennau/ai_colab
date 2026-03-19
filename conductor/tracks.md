# Project Tracks: ai-colab

This file is the Source of Truth for the project state. The Conductor Agent monitors this file for tasking and progress reporting.

## 🏁 Milestones

- [x] **Milestone 1: Unified Environment Foundation** (Done)
- [ ] **Milestone 2: Enhanced Task Coordination** (Current)
- [ ] **Milestone 3: Automated Quality Assurance** (Planned)

---

## 🏗️ Core Tracks

### 💎 **Track: Master Installer & Launcher**
- **Status:** [x] Done
- **Assigned:** @conductor
- **Description:** Implement a unified `./install.sh` and `./launch.sh` for multi-agent setup.
- **Tasks:**
  - [x] Create `./install.sh` with interactive LLM selection.
  - [x] Create `./launch.sh` with integrated Dashboard/Conductor startup.
  - [x] Integrate with `hcom` for agent registration.

### 🧠 **Track: Blackboard Task Handoffs**
- **Status:** [ ] In Progress
- **Assigned:** @conductor
- **Description:** Extend the Conductor to handle complex task handoffs between agents using `hcom-kv`.
- **Tasks:**
  - [ ] Implement `task-handoff` thread monitoring in `scripts/conductor-workflow.sh`.
  - [ ] Define standardized JSON schema for task definitions on the blackboard.
  - [ ] Add "Reviewer" role to agents via hcom.

### 🕹️ **Track: Atari-LX Hardware Context**
- **Status:** [ ] In Progress
- **Assigned:** @qwen-dev
- **Description:** Optimize agent knowledge of Atari 8-bit hardware constraints.
- **Tasks:**
  - [ ] Sync `scripts/init-atari-constants.sh` with the latest hardware maps.
  - [ ] Refine `scripts/atari-debate.sh` to include more context from the blackboard.

---

## 🛠️ Infrastructure & Maintenance

- [x] **Project Documentation:** (Done)
  - [x] Root README.md
  - [x] conductor/product.md
  - [x] conductor/tracks.md
- [ ] **Build System:** (Todo)
  - [ ] Implement a unified `make` or `npm build` command for project-wide checks.
- [ ] **Testing:** (Todo)
  - [ ] Add CI/CD checks for shell scripts (shellcheck).
