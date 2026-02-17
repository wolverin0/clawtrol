# ClawTrol Feature Diagnostic — Full Intent Analysis
> Generated 2026-02-17 by Otacon (Opus) for validation by Claude Code / Codex

## App Overview
**ClawTrol** is a kanban-style mission control for AI coding agents. 88 controllers, 44 models, 183 views, 56 services, 20 jobs, 117 JS controllers, 247 tests.

---

## 1. 📋 Kanban Core (Boards + Tasks)

### Intent
The backbone. Multiple boards as tabs, tasks with statuses (`inbox → up_next → in_progress → in_review → done → archived`), drag-and-drop, real-time updates via ActionCable.

### What it SHOULD do
- Create/edit/delete/move tasks across status columns
- Assign tasks to boards, agents, and models
- Support task dependencies (blocking/blocked_by) with circular detection
- Follow-up tasks linked to parents, with AI suggestions
- Fragment caching on task cards for performance
- Turbo Frame board switching (no full page reload)
- Lazy-load context menus and modals
- ALL aggregator view (read-only across all boards)
- Keyboard shortcuts (n=new task, Ctrl+/=terminal, ?=help)

### Cross-Feature Interactions
- **Factory** creates tasks in specific boards
- **Pipeline** triages incoming tasks, enriches context, selects model
- **Nightshift** claims and works tasks from `up_next`
- **Agent Integration** streams live agent activity into task detail
- **Notifications** fire on status changes
- **Validation** runs post-agent commands, auto-moves status
- **ZeroBitch** dispatches tasks to fleet agents
- **Swarm** launches multi-agent sessions on tasks

### Models: `Task`, `Board`, `TaskDependency`, `TaskActivity`, `TaskDiff`, `TaskRun`, `TaskTemplate`
### Controllers: `boards_controller`, `boards/tasks_controller`
### Services: `BulkTaskService`, `TaskExportService`, `TaskImportService`, `TaskFollowupService`, `TaskOutcomeService`

---

## 2. 🤖 Agent Integration

### Intent
Connect external AI agents (OpenClaw, Codex, etc.) to tasks. Agents claim tasks, stream activity, and report completion.

### What it SHOULD do
- Agent claims task via API (`POST /api/v1/tasks/:id/claim`)
- Live activity streaming via WebSocket (AgentActivityChannel) or polling (`/agent_log`)
- Spinner indicator on cards with active agents
- Agent terminal with tabbed transcript viewer, hover preview, pin-to-terminal
- Model selection per task (opus, codex, gemini, glm, sonnet, minimax)
- Session linking — `agent_complete` and `claim` accept session params
- Deep Research mode — toggle multi-agent analysis

### Cross-Feature Interactions
- **Pipeline** auto-selects model based on task complexity
- **Factory** spawns agents automatically via cron
- **Nightshift** is essentially an automated agent session
- **Notifications** fire on agent claim and completion
- **Validation** runs after agent reports completion
- **Swarm** launches parallel agent sessions

### Models: `AgentTranscript`, `AgentMessage`, `AgentPersona`, `AgentTestRecording`
### Controllers: `agent_config_controller`, `agent_personas_controller`, `terminal_controller`
### Services: `AgentCompletionService`, `AgentLogService`, `AgentAutoRunnerService`, `AgentActionRecorder`

---

## 3. 🏭 Factory v2 — Continuous Improvement Engine

### Intent
Autonomous code improvement loops. A Factory Loop watches a codebase, periodically spawns agents to find and fix issues, deduplicates findings, and reports back.

### What it SHOULD do
- Define loops with: workspace_path, github_url, branch, model, timeout, schedule
- 10 built-in factory agents (Security Auditor, Code Reviewer, Perf Profiler, Test Coverage Hunter, etc.)
- FactoryLoopAgents — assign/rotate multiple agents per loop
- StackDetector auto-detects project type (Rails, Node, Python, Rust, Go)
- PromptCompiler builds context-rich prompts with project manifests
- Cycle lifecycle: `POST /factory/loops/:id/cycles` → agent works → `POST /factory/cycles/:id/complete`
- Finding dedup via SHA256 pattern hash + confidence scoring (0-100)
- Workspace setup: git worktree isolation + DB sandbox per loop
- Play/Pause/Stop syncs with OpenClaw cron scheduler via CLI
- Cherry-pick view for reviewing and applying factory-generated commits
- Auto-feed: when backlog runs out, factory generates new improvement items

### Cross-Feature Interactions
- **Cron Jobs** — each loop is backed by an OpenClaw cron job (FactoryCronSyncService)
- **Kanban** — factory can create tasks from findings
- **Agent Integration** — factory spawns agent sessions
- **Pipeline** — could potentially route factory findings through triage
- **Notifications** — should notify on cycle completion
- **ZeroBitch** — could delegate factory work to fleet agents (future)

### Models: `FactoryLoop`, `FactoryCycleLog`, `FactoryAgent`, `FactoryAgentRun`, `FactoryLoopAgent`, `FactoryFindingPattern`
### Controllers: `factory_controller`, `factory_loops_controller`, API: `factory_loops_controller`, `factory_cycles_controller`, `factory_agents_controller`, `factory_loop_agents_controller`, `factory_finding_patterns_controller`
### Services: `FactoryEngineService`, `FactoryCronSyncService`, `FactoryPromptCompiler`, `FactoryStackDetector`, `FactoryFindingProcessor`
### Jobs: `FactoryRunnerJob`, `FactoryRunnerV2Job`, `FactoryCycleTimeoutJob`

---

## 4. ⚔️ ZeroBitch — Fleet Management

### Intent
Manage a swarm of ZeroClaw agent instances as Docker containers. Each agent has its own role, model, personality (SOUL.md), and resource limits.

### What it SHOULD do
- Fleet dashboard: list all agents with status (running/stopped), RAM, CPU, sparklines
- Spawn agents from 6 templates or custom config
- Docker lifecycle: start/stop/restart/destroy from UI
- Task dispatch: send prompts to agents, track execution history with timing
- Memory browser: browse agent SQLite databases
- Auto-scaler rules: define scaling conditions
- Metrics collection: periodic stats via ZerobitchMetricsJob
- SOUL.md / AGENTS.md editor: live edit agent personality
- Logs viewer: real-time container log streaming
- Batch operations: start/stop/restart multiple agents
- Agent detail page with tabs (overview, tasks, memory, logs)

### Cross-Feature Interactions
- **Kanban** — agents could pull tasks from boards (not yet wired)
- **Factory** — factory loops could delegate to fleet agents (future)
- **Notifications** — should notify on agent crash/restart
- **Agent Integration** — ZeroClaw agents could report via same API as OpenClaw agents
- **Analytics** — fleet metrics could feed into analytics dashboard

### Services: `Zerobitch::AgentRegistry`, `Zerobitch::DockerService`, `Zerobitch::ConfigGenerator`, `Zerobitch::FleetTemplates`, `Zerobitch::AutoScaler`, `Zerobitch::MemoryBrowser`, `Zerobitch::MetricsStore`, `Zerobitch::TaskHistory`
### Controller: `zerobitch_controller`
### Job: `ZerobitchMetricsJob`

---

## 5. 🌙 Nightshift — Autonomous Night Operations

### Intent
Automated agent work during off-hours (23:00-08:00 ART). Selects tasks, spawns agents, manages timeout/completion, reports results in the morning.

### What it SHOULD do
- Auto-select tasks from `up_next` based on priority and board config
- Spawn agent sessions with model selection and timeout
- Track missions with start/end times, outcomes, costs
- Timeout sweeper kills hung sessions
- Morning report summarizing what was accomplished
- Manual override: start/stop nightshift from UI

### Cross-Feature Interactions
- **Kanban** — pulls from `up_next`, moves to `in_progress` → `in_review`
- **Agent Integration** — spawns OpenClaw sessions
- **Pipeline** — could use pipeline for model selection
- **Factory** — nightshift could run factory loops
- **Cron Jobs** — nightshift runner is a cron job
- **Notifications** — morning report via Telegram

### Models: `NightshiftMission`, `NightshiftSelection`
### Controllers: `nightshift_controller`, `nightbeat_controller`, API: `nightshift_controller`
### Services: `NightshiftEngineService`, `NightshiftSyncService`
### Jobs: `NightshiftRunnerJob`, `NightshiftTimeoutSweeperJob`

---

## 6. 🔄 Pipeline — Intelligent Task Routing

### Intent
Auto-triage incoming tasks: classify complexity, enrich with project context, select optimal model, compile prompts. The "brain" that decides HOW a task should be worked.

### What it SHOULD do
- Triage: classify task complexity (simple/medium/complex)
- Context compilation: pull project manifests, relevant files, RAG
- Model selection: pick best available model based on task type and limits
- Orchestration: coordinate the triage → context → model → spawn flow
- QdrantClient: vector search for relevant code context

### Cross-Feature Interactions
- **Kanban** — processes tasks on status change to `up_next`
- **Agent Integration** — selects model for agent sessions
- **Factory** — could use pipeline for factory agent model selection
- **Nightshift** — could delegate model selection to pipeline
- **Analytics** — model performance data feeds back into selection

### Services: `Pipeline::Orchestrator`, `Pipeline::TriageService`, `Pipeline::ContextCompilerService`, `Pipeline::ClawRouterService`, `Pipeline::AutoReviewService`, `Pipeline::QdrantClient`
### Controller: `pipeline_dashboard_controller`
### Job: `PipelineProcessorJob`

---

## 7. ⏰ Cron Job Builder

### Intent
Manage OpenClaw scheduled jobs from ClawTrol's UI. View, create, edit, delete crons.

### What it SHOULD do
- List all cron jobs with status (enabled/disabled), schedule, last run
- Create new crons with schedule (cron expr, interval, one-shot), payload, delivery
- Edit existing cron jobs
- Delete with confirmation
- Delivery target dropdown (announce to channel)
- CRUD via OpenClaw CLI (not HTTP API)

### Cross-Feature Interactions
- **Factory** — factory loops create/manage crons via FactoryCronSyncService
- **Nightshift** — nightshift runner is a cron
- **Heartbeat** — heartbeat polling is a cron
- **ZeroBitch** — metrics collection could be a cron

### Controller: `cronjobs_controller`

---

## 8. ✅ Validation System

### Intent
Post-agent validation of task output. Run shell commands (tests, linters) to verify agent work before accepting.

### What it SHOULD do
- Define validation commands per task or use quick templates (Rails Test, npm test, Rubocop, ESLint, pytest)
- Background execution (up to 2 min timeout)
- Auto-status: pass → `in_review`, fail → stays `in_progress`
- Command sandboxing via Shellwords + allowlist
- Validation output modal showing results

### Cross-Feature Interactions
- **Kanban** — moves task status based on result
- **Agent Integration** — triggered after agent reports completion
- **Factory** — factory could use validation to verify its own fixes
- **Notifications** — notify on validation result

### Services: `ValidationRunnerService`, `ValidationSuggestionService`
### Jobs: `RunValidationJob`, `AutoValidationJob`

---

## 9. 📊 Analytics & Dashboard

### Intent
Overview of system health, agent productivity, model usage, costs.

### What it SHOULD do
- Dashboard: status cards, active agents, recent tasks, model availability
- Analytics: CSS bar charts, period filtering (24h/7d/30d/all), model usage breakdown, board breakdown
- Budget view: cost tracking per model/agent
- Cost snapshots: daily automated capture
- Session cost analytics

### Cross-Feature Interactions
- **All features** feed data into analytics
- **Agent Integration** — model usage and costs
- **Factory** — cycle costs and productivity
- **Nightshift** — mission costs
- **ZeroBitch** — fleet resource usage

### Models: `CostSnapshot`, `TokenUsage`
### Controllers: `dashboard_controller`, `analytics_controller`
### Services: `DashboardDataService`, `CostSnapshotService`, `SessionCostAnalytics`, `ModelPerformanceService`
### Presenters: `BudgetPresenter`, `CostAnalyticsPresenter`
### Job: `DailyCostSnapshotJob`

---

## 10. 🔔 Notifications

### Intent
Alert users on important events (agent claimed, task completed, validation results).

### What it SHOULD do
- In-app bell icon with unread count badge
- Browser notification API (optional)
- Mark all read
- Telegram push on task status changes
- Webhook push (JSON POST) for custom integrations
- Settings UI for Telegram bot token, chat ID, webhook URL
- Test button to verify setup

### Cross-Feature Interactions
- **Kanban** — fires on status change
- **Agent Integration** — fires on claim/completion
- **Factory** — should fire on cycle completion
- **Nightshift** — morning report
- **Validation** — fires on pass/fail

### Model: `Notification`
### Controller: `notifications_controller`
### Services: `ExternalNotificationService`, `OpenclawWebhookService`
### Job: `OpenclawNotifyJob`, `AutoClaimNotifyJob`

---

## 11. 🌊 Swarm — Multi-Agent Launcher

### Intent
Launch multiple agents on a single task or idea for parallel exploration. "Swarm intelligence" approach.

### What it SHOULD do
- Swarm launcher UI with idea submission
- Favorites, board routing, launch history
- Pipeline stepper showing triage → context → spawn flow
- Multi-agent sessions running in parallel
- Results aggregation

### Cross-Feature Interactions
- **Kanban** — creates tasks from swarm ideas
- **Agent Integration** — spawns multiple agent sessions
- **Pipeline** — uses pipeline for model selection
- **Analytics** — tracks swarm session costs

### Model: `SwarmIdea`
### Controller: `swarm_controller`

---

## 12. 🔗 Sessions Explorer

### Intent
Browse and monitor active OpenClaw sessions (main + isolated sub-agents).

### What it SHOULD do
- List sessions with status, model, last activity
- View session transcripts
- Link sessions to tasks

### Controller: `sessions_explorer_controller`
### Service: `SessionResolverService`

---

## 13. 📱 Nodes

### Intent
Manage paired OpenClaw node devices (phones, Pis, etc.).

### Controller: `nodes_controller`

---

## 14. 🧩 Skills Manager

### Intent
Browse and manage OpenClaw agent skills.

### Controller: `skill_manager_controller`
### Service: `SkillScannerService`

---

## 15. 📥 Saved Links

### Intent
Bookmark URLs for later processing — fetch, summarize, store.

### What it SHOULD do
- Save links from UI or API
- Background processing: fetch content, generate summary
- Tag and categorize

### Model: `SavedLink`
### Controller: `saved_links_controller`
### Job: `ProcessSavedLinkJob`

---

## 16. 🏆 Showcases & Outputs

### Intent
Display and share agent work outputs (code, reports, artifacts).

### Controllers: `showcases_controller`, `outputs_controller`

---

## 17. 🫀 Soul Editor

### Intent
Edit SOUL.md, AGENTS.md, USER.md — the personality/config files for the connected OpenClaw agent.

### What it SHOULD do
- Load current file content from workspace
- Edit in-browser with syntax highlighting
- Save back to workspace
- Version history
- Templates gallery

### Controller: `soul_editor_controller`

---

## 18. 🔧 Workflows

### Intent
Define multi-step workflow templates (DAGs) for complex task execution.

### What it SHOULD do
- Visual workflow editor
- Step dependencies (DAG)
- Trigger workflows on events
- Track execution progress

### Model: `Workflow`
### Controller: `workflows_controller`
### Services: `WorkflowDefinitionValidator`, `WorkflowExecutionEngine`

---

## 19. 🎮 Command Center

### Intent
Send ad-hoc commands/messages to the connected OpenClaw agent.

### Controller: `command_controller`

---

## 20. 🪙 Tokens / API Access

### Intent
Manage API tokens for external integrations.

### Model: `ApiToken` (scopes: active, expired, recently_used)
### Controller: `tokens_controller`

---

## 21. 🧠 Audits & Self-Audit

### Intent
Track agent behavioral patterns, interventions, performance over time.

### What it SHOULD do
- Audit reports with trend charts
- Behavioral interventions tracker
- Auto-update interventions from agent ingestion API

### Models: `AuditReport`, `BehavioralIntervention`
### Controllers: `audits_controller`, `behavioral_interventions_controller`

---

## 22. 📰 Feeds

### Intent
RSS/content feed aggregation and monitoring.

### Model: `FeedEntry`
### Controller: `feeds_controller`

---

## 23. 🐕 Webhooks

### Intent
Manage incoming webhook mappings — route external events to ClawTrol actions.

### Model: `WebhookLog`
### Controller: `webhook_mappings_controller`

---

## 24. ⚙️ Settings Hub

### Intent
Central configuration for all integrations: Gateway, Telegram, Discord, channels, heartbeat, compaction, DM policy, send policy, typing, sandbox, streaming, identity, media, logging, session maintenance/reset, model providers.

### Controllers (15+): `gateway_config_controller`, `telegram_config_controller`, `discord_config_controller`, `channel_config_controller`, `heartbeat_config_controller`, `compaction_config_controller`, `dm_policy_controller`, `send_policy_controller`, `typing_config_controller`, `sandbox_config_controller`, `identity_config_controller`, `media_config_controller`, `logging_config_controller`, `session_maintenance_controller`, `session_reset_config_controller`, `model_providers_controller`, `config_hub_controller`

---

## 25. 🎭 Agent Personas

### Intent
Define reusable agent personalities/roles that can be assigned to tasks.

### What it SHOULD do
- CRUD personas with name, emoji, specialty, prompt
- Roster view showing all available personas
- Auto-generate personas per board
- Assign persona to task for customized agent behavior

### Model: `AgentPersona`
### Controller: `agent_personas_controller`
### Service: `PersonaGeneratorService`

---

## 26. 🛡️ Catastrophic Guardrails

### Intent
Safety net — detect and prevent agents from doing dangerous things.

### Service: `CatastrophicGuardrailsService`
### Job: `CatastrophicGuardrailsJob`

---

## 27. 💬 Debate Mode

### Intent
Multi-agent deliberation on a task — multiple models discuss and reach consensus.

### Job: `RunDebateJob`

---

## 28. 🔐 Admin

### Intent
User management, invite codes for controlled access.

### Models: `User`, `InviteCode`
### Controllers: `admin/dashboard_controller`, `admin/users_controller`, `admin/invite_codes_controller`

---

## 29. 📊 Model Rate Limiting

### Intent
Track model availability, record rate limits, auto-fallback to backup models.

### Model: `ModelLimit`

---

## 30. 🔄 Cherry Pick (Factory)

### Intent  
Review and apply commits generated by factory loops before merging to main.

### Controller: `factory_controller#cherry_pick`
### Service: `CherryPickService`

---

## Potential Feature Interactions to Validate

| From | To | Interaction | Status |
|------|-----|------------|--------|
| Factory → Kanban | Factory findings create tasks | ❓ Verify wiring |
| Factory → Cron | Play/Pause/Stop syncs crons | ✅ FactoryCronSyncService |
| Pipeline → Agent | Model selection for spawning | ❓ Verify integration |
| Nightshift → Kanban | Claims from up_next | ✅ NightshiftEngineService |
| Nightshift → Notifications | Morning report | ❓ Verify delivery |
| Validation → Kanban | Auto-status on pass/fail | ✅ ValidationRunnerService |
| ZeroBitch → Kanban | Fleet agents pull tasks | ❌ Not wired yet |
| ZeroBitch → Factory | Fleet runs factory loops | ❌ Not wired yet |
| Swarm → Pipeline | Model selection for swarm | ❓ Verify integration |
| Agent → Notifications | Claim/completion alerts | ✅ NotifyJob |
| Factory → Notifications | Cycle completion alerts | ❓ Verify |
| Analytics ← All | Cost/usage aggregation | ❓ Verify completeness |
| Personas → Tasks | Persona assigned to task | ❓ Verify effect on prompt |
| Guardrails → Agent | Block dangerous actions | ❓ Verify enforcement |
| Debate → Tasks | Multi-model deliberation | ❓ Verify output handling |

---

## Summary Stats

| Category | Count |
|----------|-------|
| Major Features | 30 |
| Controllers | 88 |
| Models | 44 |
| Services | 56 |
| Jobs | 20 |
| Views | 183 |
| JS Controllers | 117 |
| Tests | 247 |
| API Endpoints | 25+ controllers |
| Sidebar Links | 26 |

## Validation Approach

Hand this document to Claude Code or Codex with the codebase and ask:
1. For each feature: does the code actually implement the described intent?
2. Are the cross-feature interactions wired correctly or are they broken/missing?
3. Are there dead features (controllers/models with no functioning UI)?
4. Are there orphaned routes (routes → controllers that crash)?
5. Security: are all API endpoints properly authenticated?
6. Performance: any N+1 queries remaining after the kanban fixes?
