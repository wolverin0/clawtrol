# ZeroBitch + Soul Editor — Changelog

## 2026-02-17

### 🫀 Soul Editor (NEW)
- Full markdown editor for SOUL.md, IDENTITY.md, USER.md, AGENTS.md
- Tab switching between files with unsaved changes guard
- Version history (JSON-based, max 20 entries per file, FIFO)
- Revert to any previous version (saves current before reverting)
- 6 persona templates: Minimal Assistant, Friendly Companion, Technical Expert, Creative Partner, Stern Operator, Sarcastic Sidekick
- Preview mode for templates and history entries
- Keyboard shortcuts: Ctrl+S to save, Tab inserts 2 spaces
- Bottom bar: character count, relative timestamps, unsaved indicator
- Dark theme textarea with monospace font
- Added to desktop sidebar and mobile hamburger menu
- Route: `/soul-editor`

### 🐕 ZeroBitch — ZeroClaw Fleet Management (NEW)
Fleet management dashboard for orchestrating ZeroClaw AI agent instances in Docker.

#### Phase 1 — Foundation
- `ZerobitchController` with full CRUD + action endpoints
- `Zerobitch::DockerService` — Docker CLI wrapper (list, start, stop, restart, remove, logs, run, exec_task)
- `Zerobitch::ConfigGenerator` — generates valid ZeroClaw config.toml from parameters
- `Zerobitch::AgentRegistry` — JSON-based agent metadata CRUD with auto-slug IDs and auto-port assignment (18081-18199)
- Provider mapping: OpenRouter, Groq (via OR), Cerebras (custom URL), Mistral (custom URL), Ollama
- Routes under `/zerobitch` scope
- Storage: `storage/zerobitch/{tasks,configs,workspaces}`

#### Phase 2 — Dashboard UI
- **Fleet Overview** (`/zerobitch`) — agent card grid with status badges, RAM, provider/model, quick actions
- **Stats bar** — Total Agents, Running, Stopped, Total RAM
- **Spawn Form** (`/zerobitch/agents/new`) — full agent creation: name, emoji, role, provider, model, API key, autonomy, allowed commands, SOUL.md textarea, AGENTS.md textarea, mode, resource limits
- **Agent Detail** (`/zerobitch/agents/:id`) — tabbed view: Overview, SOUL editor, AGENTS editor, Send Task, Logs
- **Stimulus controllers** — zerobitch_fleet (auto-refresh), zerobitch_spawn (form + templates), zerobitch_agent (tabs + task dispatch)
- Added "🐕 ZeroBitch" to sidebar nav and mobile menu

#### Phase 3 — Task System
- **Task Dispatch** — send prompts to agents via Docker exec, capture output with timeout handling
- **Task History** — per-agent JSON log (max 100 entries), searchable, expandable results
- **Agent Logs Viewer** — tail container logs with color coding (INFO/WARN/ERROR), configurable tail count

#### Phase 4 — Polish
- **Fleet Templates** — 6 pre-configured agent roles (Infra Monitor, Research Analyst, Security Auditor, Content Writer, Code Reviewer, Data Analyst) with one-click deploy
- **Batch Operations** — multi-select agents, bulk start/stop/delete, broadcast task to all
- **Resource Monitoring** — per-agent RAM usage bars, fleet-wide totals, metrics endpoint

#### Phase 5 — Integration
- **ClawTrol Integration** — "Run with ZeroClaw" button on task cards
- **Auto-scaling Rules** — simple condition→action rule engine (JSON-based)
- **Memory Browser** — view agent SQLite memories and workspace files

### Infrastructure
- ZeroClaw Docker fleet: multi-stage Dockerfile (Rust builder → Debian slim runtime)
- Docker Compose setup with per-agent configs, workspace mounts, SQLite volumes
- Fleet helper script (`fleet.sh`) for build/up/down/status/ask/logs
- ~3.4MB binary, <2MB RAM per agent instance
