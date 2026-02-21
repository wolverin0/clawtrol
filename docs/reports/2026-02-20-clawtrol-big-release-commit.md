# ClawTrol Big Release Commit Report — 2026-02-20

## Scope & Release Summary (by subsystem)

### 1) Codemap Monitor + Visual Layer
- Added Codemap Monitor MVP at `/codemap_monitor` with Hotel/Tech toggle UI.
- Added new JS renderers/controllers:
  - `app/javascript/codemap/renderer.js`
  - `app/javascript/codemap/hotel_renderer.js`
  - `app/javascript/controllers/codemap_monitor_controller.js`
  - `app/javascript/controllers/visualizer_controller.js`
- Added shared UI partial for task-level codemap embedding:
  - `app/views/shared/_codemap_widget.html.erb`
- Added monitor page view:
  - `app/views/codemap_monitor/index.html.erb`
- Added codemap asset placeholders and raw art assets under `public/codemap/*`.

### 2) Durable Agent Activity Persistence + Streaming
- Added `agent_activity_events` model + migration + schema updates:
  - `app/models/agent_activity_event.rb`
  - `db/migrate/20260219100000_create_agent_activity_events.rb`
  - `db/schema.rb`
- Added ingestion + broadcast services:
  - `app/services/agent_activity_ingestion_service.rb`
  - `app/services/codemap_broadcaster.rb`
- Wired integration/touch-ups across hooks/logging/channels:
  - `app/controllers/api/v1/hooks_controller.rb`
  - `app/channels/agent_activity_channel.rb`
  - `app/services/agent_log_service.rb`
  - `app/javascript/channels/index.js`
  - `lib/tasks/agent_activity.rake`

### 3) ZeroBitch / Fleet Observability + UX
- Enhanced ZeroBitch controller/service/view behavior for richer observability and task context:
  - `app/controllers/zerobitch_controller.rb`
  - `app/services/zerobitch/docker_service.rb`
  - `app/javascript/controllers/zerobitch_agent_controller.js`
  - `app/views/zerobitch/*.erb`
- Board/task surface updates to better expose controls/state:
  - `app/views/boards/_filter_bar.html.erb`
  - `app/views/boards/tasks/_panel.html.erb`
  - `app/views/boards/_task_card.html.erb`
  - `app/views/boards/_controls.html.erb`
  - `app/views/boards/_personas_sidebar.html.erb`

### 4) Reliability + Integration Hardening
- Supporting changes in task/notification/model plumbing and service contracts:
  - `app/models/task.rb`
  - `app/models/notification.rb`
  - `app/services/openclaw_webhook_service.rb`
  - `app/services/transcript_watcher.rb`
  - `app/services/openclaw_memory_search_health_service.rb`
  - `app/controllers/api/v1/tasks_controller.rb`

---

## Docs / Install / README / CHANGELOG updates

### README.md
- Added release-relevant feature bullets:
  - Durable activity event persistence in Agent Activity section.
  - New Codemap Monitor MVP section.
- Updated self-hosting install note to clarify `install.sh` behavior (safe rerun + non-destructive env append behavior for secret generation).

### CHANGELOG.md
- Updated `[Unreleased]` entries to reflect actual included work:
  - Codemap Monitor MVP
  - Durable activity telemetry persistence
  - ZeroBitch observability UX updates
  - Docs/test coverage updates aligned to committed changes
- Resolved rebase conflict while preserving both upstream changelog updates and this release notes content.

### Auto-install instructions/scripts
- Updated `install.sh`:
  - Branding text: ClawTrol naming.
  - SECRET_KEY_BASE handling now appends to `.env.production` only when missing, avoiding destructive overwrite of existing env values.

---

## Validations Run (focused, meaningful)

### A) Targeted model/service/controller tests
```bash
bin/rails test \
  test/models/agent_activity_event_test.rb \
  test/services/agent_activity_ingestion_service_test.rb \
  test/services/codemap_broadcaster_test.rb \
  test/controllers/codemap_monitor_controller_test.rb \
  test/controllers/file_viewer_controller_test.rb \
  test/controllers/zerobitch_controller_test.rb \
  test/services/openclaw_memory_search_health_service_test.rb
```
- Result: **PASS** (21 runs, 56 assertions, 0 failures, 0 errors, 3 skips)

### B) System validation for board/codemap UI
First run:
```bash
bin/rails test test/system/codemap_monitor_visual_test.rb test/system/board_test.rb
```
- Result: **FAILED initially** (selector mismatch + JS evaluate syntax issue).
- Action taken:
  - Fixed board header selector compatibility for nav dropdown targeting.
  - Wrapped JS evaluate payload in IIFE to avoid Selenium JS parse error.

Second run:
```bash
bin/rails test test/system/codemap_monitor_visual_test.rb test/system/board_test.rb
```
- Result: **PASS** (19 runs, 69 assertions, 0 failures, 0 errors).

### C) Post-rebase sanity run (same touched system area)
```bash
bin/rails test test/system/board_test.rb test/system/codemap_monitor_visual_test.rb
```
- Result: **PASS** (19 runs, 69 assertions, 0 failures, 0 errors).

---

## Divergence Resolution
- Starting state: `main` ahead 22 / behind 2.
- Performed:
  1. Commit local release work.
  2. `git fetch origin`
  3. `git rebase origin/main`
  4. Resolved single conflict in `CHANGELOG.md`.
  5. Continued rebase and re-ran focused validations.

---

## Commits & Push Target
- Main release commit: `2d88d14`  
  `feat: ship codemap monitor + durable agent activity telemetry release`
- Follow-up stabilization commit: `58f3140`  
  `test: stabilize board system login setup for deterministic selenium runs`
- Push target: `origin/main`
- Push status: **SUCCESS** (`fa7a2a8..58f3140 main -> main`)

---

## Known Follow-ups / Risks
1. Repository still contains large binary artifacts (pre-existing warning surfaced during push: `public/openclaw-2026.2.18-debug.apk` > 50MB).
2. Codemap raw asset strategy may need cleanup/LFS policy if art/sprite payload grows further.
3. Consider tightening/normalizing system-test auth helper usage across classes to avoid intermittent login fixture drift.

---

## Final Outcome
- Release commit prepared, rebased cleanly on latest `origin/main`, validated with focused tests, and pushed successfully.
