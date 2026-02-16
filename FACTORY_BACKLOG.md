# Factory Backlog — Features & Improvements to Implement

Priority order. MiniMax: pick the top unchecked item, implement it, mark [x] when done.

## 🔴 HIGH PRIORITY — OpenClaw Deep Integration

- [x] **Plugin Status Widget**: Call OpenClaw Gateway API (`/api/v1/gateway/health`) to show installed plugins (voice-call, memory-lancedb, matrix, nostr, etc), their enabled/disabled state, and config. Display as a dashboard widget with toggle controls
- [x] **Node Dashboard**: OpenClaw supports paired nodes (iOS/Android/macOS/headless) with camera, canvas, location, screen recording, SMS. Build a `/nodes` page showing: paired nodes list, connection status (online/offline), device info, and quick action buttons (camera snap, screenshot, locate, send notification). Use the Gateway API for node status
- [x] **Cherry-Pick Pipeline**: Add a "Cherry-Pick to Production" button on the Factory Playground page. Flow: select commits → preview diff → one-click `git cherry-pick` to `~/clawdeck` → run tests → show result. Include conflict resolution UI
- [x] **Agent Cost Analytics v2**: Extend existing cost tracking with: cost breakdown per cron job (correlate session costs with cron job IDs), cost per Factory cycle, daily/weekly/monthly trends chart, projected monthly spend, configurable budget alerts. Store in a new `cost_snapshots` table
- [x] **Session Explorer**: Build a `/sessions` page that queries OpenClaw's session store. Show: active sessions (main, cron, hook, subagent), token usage per session, last activity, compaction count, model used. Link sessions to ClawTrol tasks. Allow viewing session transcripts
- [x] **Gateway Config Editor**: OpenClaw supports hot-reload config changes. Build a visual config editor in ClawTrol that reads the current config via Gateway RPC, renders a form (models, tools, channels, hooks, cron), and writes changes back. Show which fields need restart vs hot-apply

## 🟡 MEDIUM PRIORITY — Multi-Agent & Automation

- [x] **Multi-Agent Config UI**: OpenClaw supports multiple isolated agents with separate workspaces, auth, sessions, and bindings. Build a `/agents` config page: list agents, edit workspace/model/tools per agent, manage channel→agent bindings visually (drag-drop routing), configure tool profiles (minimal/coding/messaging/full) per agent
- [x] **Webhook Mapping Builder**: OpenClaw supports `hooks.mappings` with match rules, templates, and JS transforms. Build a visual builder: define source matching (GitHub, n8n, custom), action type (wake/agent), template variables, delivery config. Preview the generated JSON mapping. Save directly to OpenClaw config
- [x] **Exec Approvals Manager**: OpenClaw has per-node command allowlists (`~/.openclaw/exec-approvals.json`). Build a UI to manage these: show current allowlist per node, add/remove commands, bulk import from audit logs, show recent exec history with approve/deny actions
- [x] **Memory Plugin Dashboard**: OpenClaw has memory-core (SQLite vector) and memory-lancedb (auto-recall/capture) plugins. Build a widget showing: total memory entries, last indexed timestamp, index size, recent memory writes, and a search preview (type a query → show top results with scores). Support QMD backend stats too
- [x] **Cron Job Manager v2**: Enhance the existing cron integration. Add: visual cron expression builder (click-to-schedule), run history with duration/status charts, delivery config editor (announce/none, channel targeting), model override picker, one-click enable/disable, estimated next 5 run times preview
- [x] **Compaction Dashboard**: Track session compaction events. Show: compaction count per session, context window usage (% filled), memory flush status (did it write?), compaction summaries. Alert when sessions compact too frequently (sign of inefficient tool use)

## 🟢 NICE TO HAVE — UX & Polish

- [x] **Telegram Mini App**: Expose ClawTrol as a Telegram Mini App (WebApp). Quick task creation, status checks, approve/reject from Telegram inline without opening browser. Use Telegram Bot API `web_app_data`
- [x] **Public Status Page**: `/status` endpoint (no auth) showing: gateway health (up/down), channel status (WhatsApp/Telegram/Discord connected?), last heartbeat time, node count, uptime. Useful for monitoring from phone
- [x] **Session Identity Links UI**: OpenClaw supports `session.identityLinks` to map the same person across channels (telegram:123 = discord:456). Build a UI to manage these mappings visually
- [x] **Skill Browser**: Show installed OpenClaw skills (bundled + workspace + managed), their gating requirements (bins, env, config), enabled status, and ClawHub sync status. One-click install from ClawHub registry
- [x] **ERB/View Refactoring Sprint**: Extract repeated view patterns into partials. Improve mobile responsiveness. Add loading skeletons for async widgets. Consolidate CSS utility classes
- [x] **Real-time Gateway Events**: OpenClaw streams agent events via WebSocket. Build a live event feed in ClawTrol showing: tool calls in progress, model responses streaming, cron executions, webhook hits. Like a "mission control" live view
- [x] **DM Scope Security Audit Widget**: OpenClaw has `session.dmScope` settings critical for multi-user setups. Show current DM isolation mode, warn if `main` (shared) with multiple senders, link to fix
- [x] **Block Streaming Config**: OpenClaw has `blockStreaming` for chunked message delivery. Build a config UI with live preview of chunk sizes, coalesce settings, and per-channel overrides

## 🔴 HIGH PRIORITY — OpenClaw Feature Parity (NEW)

- [x] **Canvas/A2UI Push Dashboard**: OpenClaw has Canvas (port 18793) + A2UI framework. Build a `/canvas` page that lets admin compose A2UI HTML widgets (task cards, factory progress, cost summary) and push them to connected nodes (phone/tablet) via WebSocket. Include preset templates for common dashboards. Agent calls `canvas(action="a2ui_push")` to push
- [x] **Webchat Embed**: OpenClaw has built-in webchat at port 18789. Embed it as an iframe/component inside ClawTrol so admin can chat with Otacon directly from the task dashboard without switching apps. Add context injection: "I'm looking at task #N" when opening chat from a task
- [x] **Audio/Video Transcription Config**: OpenClaw supports audio transcription (`tools.media.audio`) with OpenAI Whisper and video analysis (`tools.media.video`) with Gemini. Build a config UI: enable/disable, select provider/model, set max file size, test with sample upload. Show transcription history
- [x] **Multi-Account Channel Manager**: OpenClaw supports multi-account per channel (WhatsApp personal + biz, multiple Telegram bots, etc). Build a UI to manage accounts: add/remove, set per-account DM policy, allowFrom, sendReadReceipts. Visual routing of accounts → agents via bindings
- [x] **DM Policy & Pairing Manager**: OpenClaw has 4 DM policies (pairing/allowlist/open/disabled) + group policies. Build a visual security config: per-channel DM policy selector, allowFrom list editor, pairing code approval queue, group allowlist manager. Show who's currently paired
- [x] **Message Queue Config**: OpenClaw has sophisticated message queuing (`routing.queue`): collect mode, debounce, cap, drop strategy, per-channel overrides. Build a visual config: queue mode picker, debounce slider, cap setting, per-channel override table. Show queue depth in real-time

## 🟡 MEDIUM PRIORITY — Advanced Config & Automation (NEW)

- [x] **Session Reset Policy Editor**: OpenClaw has complex session reset rules: mode (daily/idle/never), atHour, idleMinutes, resetByChannel, resetByType (direct/group/thread), resetTriggers. Build a visual editor with timeline preview showing when sessions would reset
- [x] **Heartbeat Config Dashboard**: OpenClaw heartbeat has many knobs: interval, model, target channel, prompt, ackMaxChars, includeReasoning. Build a config form + show heartbeat history (last N runs, tokens burned, responses). Warn if heartbeat model is expensive
- [x] **Compaction & Context Pruning Config**: OpenClaw has `compaction` (safeguard mode, memoryFlush) and `contextPruning` (cache-ttl, soft/hard trim ratios). Build unified config UI: compaction mode picker, memoryFlush toggle, pruning TTL slider, trim ratio adjusters. Show current context usage per session
- [x] **Sandbox Config Builder**: OpenClaw Docker sandboxing has 20+ options: mode, scope, workspace access, Docker image, network, resource limits, seccomp, apparmor, browser sandbox. Build a visual builder with presets (minimal/standard/full) and per-agent overrides
- [x] **Custom Model Provider Registry**: OpenClaw supports custom model providers (`models.providers`) with baseUrl, apiKey, custom headers, model definitions with cost/context/capabilities. Build a UI to add/edit/test custom providers. Include model testing (send test prompt, measure latency)
- [x] **CLI Backend Config**: OpenClaw supports `cliBackends` for text-only fallback (claude-cli, custom CLIs). Build a UI to configure backends: command, args, model/session/image arg mappings. Show fallback chain and test connectivity
- [x] **Hooks & Gmail PubSub Dashboard**: OpenClaw has webhook mappings with match rules, templates, JS transforms + Gmail PubSub integration (label watch, auto-renew). Build a dashboard: active hooks list, recent hit log, transform editor (JS), Gmail watch status, renewal timer
- [x] **Send Policy & Access Groups**: OpenClaw has `session.sendPolicy` with rules (allow/deny by channel/chatType) and access groups for command authorization. Build a visual rule builder: drag-drop rules, per-channel overrides, access group membership editor
- [x] **Block Streaming & Human Delay Config**: OpenClaw has detailed streaming config: blockStreamingChunk (min/max chars), breakPreference (paragraph/newline/sentence), coalesce idle, humanDelay (off/natural/custom). Build per-channel streaming preview with live simulator showing how messages would chunk
- [x] **Identity & Branding Config**: OpenClaw has `identity` (name, theme, emoji, avatar), `messages` (prefix, responsePrefix, ackReaction, ackReactionScope). Build a branding page: set bot name/emoji/avatar, preview how messages look per channel, configure ack reactions
- [x] **Typing Indicator Config**: OpenClaw has 4 typing modes (never/instant/thinking/message) + interval. Build a config form with per-channel preview. Show when typing is active across sessions
- [x] **Session Maintenance Config**: OpenClaw has session store maintenance: pruneAfter, maxEntries, rotateBytes. Build a health dashboard: session count, total size, oldest session, pruning schedule. One-click cleanup of stale sessions

## 🟢 NICE TO HAVE — Integrations & Polish (NEW)

- [x] **Skill Manager with ClawHub Sync**: OpenClaw has `skills` config: allowBundled, load.extraDirs, install preferences (brew/npm), per-skill entries with env/config. Build a full skill manager: browse ClawHub, install/uninstall, configure per-skill env vars, enable/disable, show which skills are active per session
- [x] **Telegram Advanced Config**: OpenClaw Telegram has many options we don't expose: customCommands, draftChunk streaming, linkPreview, streamMode (off/partial/block), retry policy, webhook mode, proxy support, per-topic config with skills + systemPrompt. Build a full Telegram config page
- [x] **Discord Advanced Config**: OpenClaw Discord has guild-level config: per-channel allow/mention/skills/systemPrompt, per-user allowlist, reaction notification modes (off/own/all/allowlist), actions granular toggles (reactions/stickers/polls/permissions/threads/pins/search/moderation), maxLinesPerMessage. Build a visual guild config editor
- [x] **Logging & Debug Config**: OpenClaw has `logging` (level, file, consoleLevel, consoleStyle, redactSensitive) and debug commands. Build a log viewer: tail gateway logs, filter by level, search, toggle redaction. Enable /debug and /bash commands from UI
- [x] **Environment Variable Manager**: OpenClaw reads env from multiple sources (.env, config inline, shell import) with ${VAR} substitution. Build a UI: show all resolved env vars (redacted), edit .env file, test substitution, show shellEnv import status
- [x] **Mattermost/Slack/Signal Config Pages**: We have Telegram-focused config. Add pages for other channels: Mattermost (chatmode: oncall/onmessage/onchar), Slack (socket vs HTTP mode, slash commands, thread config), Signal (reaction modes). Each with channel-specific options
- [x] **Hot Reload Monitor**: OpenClaw has config hot reload with modes (hybrid/hot/restart/off) and debounce. Show reload mode, recent reload events, which changes were hot-applied vs required restart. Visual diff of config changes
- [x] **File Viewer HTML Renderer**: Currently the file viewer shows HTML as raw code. For `.html` files, render them in an iframe instead of showing source code. Add toggle between "source" and "preview" modes

## 🔴 HIGH PRIORITY — Testing & Quality (Sprint 2)

- [x] **Job Tests: FactoryRunnerJob**: Full test coverage — mock gateway client, test backlog parsing, cycle counting, error handling, lease acquisition. Target: 15+ tests
- [x] **Job Tests: NightshiftRunnerJob**: Test mission selection, time window validation, model assignment, parallel launch limits, timeout handling. Target: 15+ tests
- [x] **Job Tests: ProcessSavedLinkJob**: Test URL fetch, summary generation, error states (timeout, 404, paywall), status transitions. Target: 10+ tests
- [x] **Job Tests: TranscriptCaptureJob**: Test session key lookup, transcript fetch via gateway client, storage, offset tracking. Target: 10+ tests
- [x] **System Tests: Board Kanban**: Turbo-powered drag-drop, status transitions, task card rendering, filter/sort, empty states. Target: 8+ system tests
- [x] **System Tests: Swarm Launcher**: Idea selection, model picker, board assignment, launch flow, history display. Target: 6+ system tests
- [ ] **Model Tests: All 34 models**: Currently only 4 model test files. Add validation tests, scope tests, association tests for remaining 30 models. Target: 100+ tests across all models

## 🟡 MEDIUM PRIORITY — Refactoring & Performance

- [x] **Split TasksController (891 lines) (partial)**: Extract API::V1::TasksController into concerns — agent lifecycle already extracted, now extract: bulk operations, filtering/search, export, recurring tasks. Each concern <100 lines
- [x] **Split MarketingController (643 lines) (partial)**: Extract into sub-controllers or service objects — content generation, campaign management, analytics, social posting
- [x] **N+1 Query Audit**: Add `strict_loading` to key associations. Run `bullet` gem in test suite. Fix all N+1s in board views, task lists, analytics pages. Document eager loading patterns
- [ ] **Stimulus Controller Tests**: 106 Stimulus controllers with 0 JS tests. Add Jest/Vitest setup + test the 10 most critical controllers (task_card, board, drag_drop, form, search, chart, modal, toast, filter, websocket)
- [x] **API Rate Limiting**: Add Rack::Attack or similar for API endpoints. Rate limit per-token, with higher limits for internal (gateway) calls. Log rate-limited requests
- [x] **Database Indexes Audit**: Analyze slow queries from Rails logs. Add missing indexes on foreign keys, status columns, date ranges. Run EXPLAIN on top 10 queries

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

- [ ] **Ralph Loop Integration**: Study vercel-labs/ralph-loop-agent. Evaluate if we can use external verification + stop hooks for complex tasks instead of manual phase management
- [ ] **Multi-tenant Support**: user_id scoping is started (nightshift, factory). Complete for all models. Add team/org concept for future scaling
- [ ] **Canvas/A2UI Surface**: OpenClaw nodes support A2UI (JSONL-driven UI). Evaluate pushing ClawTrol task cards/dashboards directly to mobile nodes as Canvas surfaces instead of web browser

---

## ✅ COMPLETED (Previous Backlog)

<details>
<summary>Click to expand completed items</summary>

### ClawRouter Architecture (all done)
- [x] Pipeline Stage Field
- [x] Pipeline Config YAML
- [x] ClawRouterService
- [x] Context Compiler Service
- [x] Phase Handoff in HooksController
- [x] Pipeline Progress UI

### X Feed Intelligence & Saved Links (all done)
- [x] Manifest-Driven Task Execution
- [x] GitHub Agentic Workflows Integration
- [x] Playwright-style Agent Testing
- [x] Agent Cost Dashboard Widget
- [x] Command Palette Enhancements (Ctrl+K)
- [x] Bulk Operations UI
- [x] Task Templates with Pipeline Presets
- [x] Saved Links Integration

### Nightshift & General (all done)
- [x] Factory Progress Page
- [x] Nightshift Mission Planner AI
- [x] Agent-to-Agent Chat History
- [x] Task Dependency Graph Visualization
- [x] Model Performance Comparison
- [x] Webhook Activity Log
- [x] Dark Mode Improvements
- [x] RSS/Feed Monitor Dashboard
- [x] Mobile-First Task Creation
- [x] Export/Import Tasks

</details>

## 🔴 HIGH PRIORITY — Repo Analysis Items (from 2026-02-15)

- [ ] **Codex MCP Async Integration**: Add an async task queue page inspired by codex-mcp-async. Show running Codex tasks, filter thinking logs (95% token savings), parallel execution status. Integrate with existing session explorer
- [ ] **PAI-Style Hook Bus**: Implement an event bus / hook system inspired by Personal_AI_Infrastructure. Goal-oriented task triggers, continuous learning signals from completed tasks, cross-board event routing. New model + controller + Stimulus
- [ ] **Persona Schema Upgrade (YAML)**: Upgrade AgentPersona to support YAML-based definitions inspired by Nerve ADK. Add YAML import/export, typed tool declarations, workflow definitions, evaluation mode config. Extend existing persona model + views
- [ ] **Android Capability Extension**: Add Android device control panel inspired by android-mcp-server. ADB command execution, screenshot capture, UI layout analysis, package management. New /devices page extending existing node dashboard concept
- [ ] **Desktop Automation Sandbox**: Add desktop automation config page for Spongecake-style Docker containers. Container lifecycle management (start/stop/status), noVNC embed, action queue (click/type/screenshot), session recording. New controller + views
- [ ] **Packaged Capability Model**: Add a "Capabilities" registry inspired by make-it-heavy's tool packaging. Each capability = name + tools + config + cost estimate. Capabilities attach to boards/tasks. New model CapabilityPack, CRUD UI, assignment to tasks
