# Factory Backlog — Pending Items

Priority order. MiniMax: pick the top unchecked item, implement it, mark [x] when done.

## 🔴 HIGH PRIORITY — Testing & Quality (Sprint 2)

- [ ] **Job Tests: FactoryRunnerJob**: Full test coverage — mock gateway client, test backlog parsing, cycle counting, error handling, lease acquisition. Target: 15+ tests

- [ ] **Job Tests: NightshiftRunnerJob**: Test mission selection, time window validation, model assignment, parallel launch limits, timeout handling. Target: 15+ tests

- [ ] **Job Tests: ProcessSavedLinkJob**: Test URL fetch, summary generation, error states (timeout, 404, paywall), status transitions. Target: 10+ tests

- [ ] **Job Tests: TranscriptCaptureJob**: Test session key lookup, transcript fetch via gateway client, storage, offset tracking. Target: 10+ tests

- [ ] **System Tests: Board Kanban**: Turbo-powered drag-drop, status transitions, task card rendering, filter/sort, empty states. Target: 8+ system tests

- [ ] **System Tests: Swarm Launcher**: Idea selection, model picker, board assignment, launch flow, history display. Target: 6+ system tests

- [ ] **Model Tests: All 34 models**: Currently only 4 model test files. Add validation tests, scope tests, association tests for remaining 30 models. Target: 100+ tests across all models

## 🟡 MEDIUM PRIORITY — Refactoring & Performance

- [ ] **Split TasksController (891 lines)**: Extract API::V1::TasksController into concerns — agent lifecycle already extracted, now extract: bulk operations, filtering/search, export, recurring tasks. Each concern <100 lines

- [ ] **Split MarketingController (643 lines)**: Extract into sub-controllers or service objects — content generation, campaign management, analytics, social posting

- [ ] **Stimulus Controller Tests**: 106 Stimulus controllers with 0 JS tests. Add Jest/Vitest setup + test the 10 most critical controllers (task_card, board, drag_drop, form, search, chart, modal, toast, filter, websocket)

- [ ] **Database Indexes Audit**: Analyze slow queries from Rails logs. Add missing indexes on foreign keys, status columns, date ranges. Run EXPLAIN on top 10 queries

## 🟢 NICE TO HAVE — New Features

- [ ] **Task Templates Library**: Pre-built task templates for common operations (deploy, audit, research, bug fix). Template = title pattern + description skeleton + tags + model suggestion + board. Quick-create from template picker

- [ ] **Bulk Task Import (CSV/JSON)**: Upload CSV/JSON → preview → create tasks in batch. Useful for migrating backlogs or seeding boards. Map columns to task fields with drag-drop

- [ ] **Task Time Tracking**: Auto-track time from in_progress→done. Show per-task duration, per-board throughput, agent velocity (tasks/day). Historical charts

- [ ] **Notification Center**: In-app notification bell. Aggregate: task completions, factory cycles, nightshift results, failed jobs, budget alerts. Mark read/unread. Link to source

- [ ] **Board Templates**: Clone a board with its config (pipeline stages, agent persona, default model). Pre-built templates: "Dev Sprint", "Research Queue", "Content Pipeline"

- [ ] **Keyboard Shortcuts**: Vim-style navigation (j/k through tasks, enter to open, x to complete, / to search). Help overlay with ?. Make power users faster

- [ ] **Dark Mode Polish**: Fix remaining contrast issues in charts, code blocks, and third-party embeds. Add auto-detect (prefers-color-scheme). Per-user toggle persisted in settings

- [ ] **Mobile PWA**: Add service worker + manifest.json. Offline task viewing, push notifications for completions, home screen installable. Test on iOS Safari + Android Chrome

## ⚪ RESEARCH ITEMS — Evaluate Before Implementing
---



- [ ] **Canvas/A2UI Surface**: OpenClaw nodes support A2UI (JSONL-driven UI). Evaluate pushing ClawTrol task cards/dashboards directly to mobile nodes as Canvas surfaces instead of web browser

(YAML)**: Upgrade AgentPersona to support YAML-based definitions inspired by Nerve ADK. Add YAML import/export, typed tool declarations, workflow definitions, evaluation mode config. Extend existing persona model + views

- [ ] **Android Capability Extension**: Add Android device control panel inspired by android-mcp-server. ADB command execution, screenshot capture, UI layout analysis, package management. New /devices page extending existing node dashboard concept

- [ ] **Desktop Automation Sandbox**: Add desktop automation config page for Spongecake-style Docker containers. Container lifecycle management (start/stop/status), noVNC embed, action queue (click/type/screenshot), session recording. New controller + views



- [ ] **Activity Feed / Timeline**: Vista cronológica de eventos — task moves, agent spawns, completions, deploys, errores. Filtrable por board/agent/tipo. Nuevo controller + Turbo Stream para real-time. Ruta: /activity

- [ ] **Task Dependencies / Blockers visuales**: Campo `depends_on_task_id` en Task. Mostrar líneas de dependencia en kanban. Bloquear auto-runner si dependencia no está done. UI: selector de dependencia en task panel

- [ ] **Quick Actions desde Kanban**: Hover sobre task card → botones flotantes: ▶️ Run, 🔄 Requeue, ✅ Done, 📋 Clone. Sin abrir el panel. Stimulus controller con Turbo

- [ ] **Saved Filters / Views**: Guardar combinaciones de filtros como views nombradas. Model SavedView (name, filters JSON, user_id). Tabs rápidos arriba del board

- [ ] **Diff Viewer integrado**: Cuando agent modifica archivos, mostrar git diff side-by-side en task panel. Parsear output_files + git log → HTML diff rendered

- [ ] **Agent Leaderboard / Stats**: Dashboard /stats con métricas por modelo — success rate, avg duration, tasks/día, fail rate. Charts con Chartkick. Comparar modelos side-by-side

- [ ] **Pinned Tasks / Favorites**: Pin tasks al top del board o sidebar "watching". Model TaskPin (user_id, task_id). Toggle pin desde card y panel

- [ ] **GitHub Commits en Task Panel**: Si agent hizo commits, mostrar SHAs + message inline en task panel. Extraer de agent transcript o git log post-completion

- [ ] **Webhook Log Viewer**: Página /webhooks/logs con todos los webhooks in/out — payload, response code, timing, retry count. Model WebhookLog. Filtrable por status/type
