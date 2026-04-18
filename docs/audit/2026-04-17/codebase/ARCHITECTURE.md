# ClawTrol Architecture

**Date:** 2026-04-17
**Scope:** `focus=arch` — architectural layering, cross-cutting concerns, real-time/background infrastructure, and entry points.
**Codebase root:** `/home/ggorbalan/clawdeck/`
**Stack:** Rails 8.1 (`config/application.rb` → `config.load_defaults 8.1`), SQLite + SolidQueue + SolidCable + SolidCache, Turbo/Hotwire, Tailwind.

---

## 1. High-level architecture

ClawTrol is a monolithic Rails 8.1 application acting as a mission-control Kanban for AI agents. It exposes:

- **A HTML/Turbo Streams app** for the operator UI (kanban boards, config pages, dashboards) under `app/controllers/*.rb` (~81 controllers) and `app/views/` (~82 view folders).
- **A JSON API** under `app/controllers/api/v1/` (30 controllers) consumed by external agents (OpenClaw, Codex sandbox, hooks) and by browser polling.
- **Real-time channels** via ActionCable (5 channels in `app/channels/`) mounted at `/cable`.
- **Background jobs** via SolidQueue (29 jobs in `app/jobs/`), scheduled via `config/recurring.yml`.

The **central domain model is `Task`** (`app/models/task.rb`, 287 lines, split across 5 concerns in `app/models/task/`). Tasks belong to a `Board`, are owned by a `User`, and flow through a kanban of statuses: `inbox → up_next → in_progress → in_review → done | archived | needs_decision`.

### Core entity map (60 tables in `db/schema.rb`)

| Cluster | Tables |
|---|---|
| Kanban core | `tasks`, `boards`, `task_activities`, `task_dependencies`, `task_runs`, `task_diffs`, `task_templates` |
| Agents | `agent_personas`, `agent_messages`, `agent_transcripts`, `agent_activity_events`, `agent_test_recordings`, `zeroclaw_agents`, `runner_leases`, `background_runs` |
| Auth | `users`, `sessions`, `api_tokens`, `invite_codes` |
| Factory (agent-loop orchestration) | `factory_loops`, `factory_agents`, `factory_loop_agents`, `factory_cycle_logs`, `factory_agent_runs`, `factory_finding_patterns` |
| Nightshift (overnight batches) | `nightshift_missions`, `nightshift_selections` |
| OpenClaw bridge | `openclaw_flows`, `openclaw_integration_statuses`, `webhook_logs` |
| Swarm / learning | `swarm_ideas`, `learning_proposals`, `learning_effectiveness`, `behavioral_interventions`, `audit_reports` |
| Content / feeds | `saved_links`, `feed_entries`, `brain_dumps`, `notifications`, `board_roadmaps`, `board_roadmap_task_links`, `board_file_refs`, `board_project_files` |
| Cost / observability | `cost_snapshots`, `token_usages`, `model_limits` |
| Rails internals | `active_storage_*`, `solid_queue_*`, `solid_cable_messages` |

---

## 2. Layering

ClawTrol uses a **pragmatic MVC + service-object layering** — not a strict hexagonal/onion architecture. The control flow differs between HTML and API paths:

### 2.1 HTML flow (operator UI)

```
Browser (Turbo/Stimulus)
    ↓  HTTP (cookie session)
ApplicationController (app/controllers/application_controller.rb)
    ↓  Authentication concern (app/controllers/concerns/authentication.rb)
Feature controllers (boards/, admin/, *_config, etc.)
    ↓  Mostly direct ActiveRecord
Models (Task, Board, …) + Service objects (app/services/**/*.rb, ~85 files)
    ↓  after_commit callbacks
Broadcasting (Turbo Streams + ActionCable — see §5)
```

Controllers read/write ActiveRecord models **directly**; services are pulled in for cross-cutting workflows (import/export, AI suggestions, notification dispatch, persona generation, transcript handling, pipeline orchestration, etc.). There is no repository layer.

### 2.2 API flow

```
Agent / external client
    ↓  HTTPS + Authorization: Bearer <token>
Rack::Attack (config/initializers/rack_attack.rb) — global throttles, see §4.3
    ↓
Api::V1::BaseController (app/controllers/api/v1/base_controller.rb)
  includes Api::TokenAuthentication  → app/controllers/concerns/api/token_authentication.rb
  includes Api::RateLimitable        → app/controllers/concerns/api/rate_limitable.rb
  default: rate_limit!(limit: 120, window: 60)
    ↓
Api::V1::* controllers (30 resources, incl. TasksController — 1038 lines)
    ↓  split into task-concerns:
    - Api::TaskAgentLifecycle        (app/controllers/concerns/api/task_agent_lifecycle.rb)
    - Api::TaskDependencyManagement  (app/controllers/concerns/api/task_dependency_management.rb)
    - Api::TaskPipelineManagement    (app/controllers/concerns/api/task_pipeline_management.rb)
    - Api::TaskValidationManagement  (app/controllers/concerns/api/task_validation_management.rb)
    - Api::TaskFiltering             (app/controllers/concerns/api/task_filtering.rb)
    ↓
Models + Services + Jobs (async work)
    ↓
JSON render  (only one explicit serializer: app/serializers/task_serializer.rb)
```

Most API endpoints render JSON **inline** (hashes built in the controller). Only `Task` has a dedicated serializer. Presenters exist (`app/presenters/budget_presenter.rb`, `cost_analytics_presenter.rb`) but are scoped to analytics views.

### 2.3 `Task` model is fat-but-organized

`app/models/task.rb` (287 lines) mixes in 5 concerns from `app/models/task/`:

| Concern | Responsibility |
|---|---|
| `Task::Broadcasting` | Turbo Streams + `KanbanChannel` + `TaskUpdatesChannel` broadcasts on create/update/destroy |
| `Task::Recurring` | Recurrence-rule cloning (`daily`/`weekly`/`monthly`) |
| `Task::TranscriptParsing` | Parse OpenClaw agent transcripts into per-task messages |
| `Task::DependencyManagement` | Blocking relationships via `task_dependencies` |
| `Task::AgentIntegration` | Session-key bookkeeping, agent claim/unclaim |
| `ValidationCommandSafety` (`app/models/concerns/validation_command_safety.rb`) | Reject shell metacharacters / enforce allow-list of command prefixes |

Callbacks drive a lot of behaviour: `after_create` auto-assigns `up_next` tasks to agents; `after_commit` fires `OpenclawNotifyJob` when a task flips to `in_progress` **and** `OPENCLAW_AUTO_SPAWN_ON_IN_PROGRESS=true`; `after_update` creates `Notification` rows on status change; `before_create` sets default Telegram `origin_chat_id`/`origin_thread_id` for Mission Control routing.

---

## 3. Entry points

### 3.1 HTTP routes (`config/routes.rb`, 691 lines)

| Group | Mount point | Purpose |
|---|---|---|
| Health | `GET /health`, `GET /up` | Liveness probes (Rails::HealthController + custom) |
| ActionCable | `/cable` | WebSocket endpoint for all channels |
| JSON API | `/api/v1/**` | Agents, hooks, tasks, boards, factory, nightshift, etc. |
| Admin | `/admin/**` | Users, invite codes (requires `require_admin`) |
| Auth | `/session`, `/registration`, `/auth/:provider/callback` (GitHub OmniAuth), `/passwords` | Session + OAuth + password reset |
| Operator UI | `/boards/**`, `/factory`, `/nightshift`, `/swarm`, `/analytics`, `/terminal`, `/canvas`, `/command`, `/marketing`, `/webchat`, `/telegram_app`, `/mission_control`, `/live`, `/status` | Feature dashboards |
| Config hub | `/config` + ~25 `*-config` paths | Per-subsystem config editors |
| Webhooks / hooks | `POST /api/v1/hooks/{agent_complete,task_outcome,agent_done,runtime_events}` | OpenClaw → ClawTrol push |
| PWA | `/manifest`, `/service-worker` | Progressive web app |
| Root | `/` → redirect `/boards/1` | |

`/api/v1/tasks` is the richest resource: it exposes ~30 collection/member actions (claim, unclaim, requeue, assign, move, handoff, link_session, dispatch_zeroclaw, run_lobster, resume_lobster, spawn_via_gateway, revalidate, run_debate, complete_review, recover_output, generate_followup, …).

### 3.2 ActionCable channels (`app/channels/`)

| Channel | File | Stream | Purpose |
|---|---|---|---|
| `KanbanChannel` | `app/channels/kanban_channel.rb` | `kanban_board_<id>` | Board-level refresh signal with `old_status`/`new_status` for sound effects |
| `TaskUpdatesChannel` | `app/channels/task_updates_channel.rb` | `task_updates_<user_id>` | Per-user cross-board task change feed |
| `AgentActivityChannel` | `app/channels/agent_activity_channel.rb` | agent-status updates (session_id/claim/status changes) |
| `ChatChannel` | `app/channels/chat_channel.rb` | Operator <-> agent chat |
| `TerminalChannel` | `app/channels/terminal_channel.rb` | `/terminal` shell pane |
| (base) | `app/channels/application_cable/{connection,channel}.rb` | `identified_by :current_user` via `Session.find_by(id: cookies.signed[:session_id])` |

All channels authenticate via the same signed-cookie session as the HTML app (see `app/channels/application_cable/connection.rb`).

### 3.3 Webhooks / inbound pushes

- `POST /api/v1/hooks/agent_complete`, `/hooks/task_outcome`, `/hooks/agent_done`, `/hooks/runtime_events` → `app/controllers/api/v1/hooks_controller.rb` with a dedicated `Api::HookAuthentication` concern (`app/controllers/concerns/api/hook_authentication.rb`) validating a shared token (`ENV["HOOKS_TOKEN"]` / `CLAWTROL_HOOKS_TOKEN`, declared in `config/application.rb`).
- `POST /api/v1/audits/ingest` — agent audit reports from ZeroClaw.
- `POST /api/v1/feed_entries` — n8n pushes RSS items.
- `POST /api/v1/gateway/*`, `/api/v1/openclaw_flows/sync` — gateway/openclaw bridge.

---

## 4. Cross-cutting concerns

### 4.1 Authentication (`app/controllers/concerns/authentication.rb`)

- **Session-based** for HTML: signed cookie `session_id` → `Session` record → `Current.user` (via `ActiveSupport::CurrentAttributes` in `app/models/current.rb`).
- Cookie flags: `httponly: true`, `same_site: :strict`, `secure: Rails.env.production?`, 30-day expiry.
- `ApplicationController` `include Authentication` → global `before_action :require_authentication`; opt out with `allow_unauthenticated_access` class-method helper.
- `require_admin` raises `ActionController::RoutingError("Not Found")` to hide admin routes from non-admins.
- OAuth: GitHub via OmniAuth → `app/controllers/omniauth_callbacks_controller.rb` (initializer: `config/initializers/omniauth.rb`).

- **Token-based** for API (`app/controllers/concerns/api/token_authentication.rb`): `Authorization: Bearer <token>` → `ApiToken.authenticate`. Falls back to the signed cookie for browser-originated API calls (so `/api/v1/tasks/:id/agent_log` works from the UI). Reads `X-Agent-Name`/`X-Agent-Emoji` headers to update the caller's agent display info.

### 4.2 Authorization

No `CanCan`/`Pundit` layer. Authorization is **scope-based**: controllers filter queries via `current_user.boards`, `current_user.tasks`, etc. `KanbanChannel#subscribed` rejects when `current_user.boards.find_by(id: board_id)` returns nil. Admin-only actions use the `require_admin` class method.

### 4.3 Rate limiting — two layers

1. **Global (Rack middleware):** `config/initializers/rack_attack.rb` via `config.middleware.use Rack::Attack` in `config/application.rb`.
   - Safelists internal requests (`X-Internal-Request: true`, `127.0.0.1`, `192.168.100.*`, and own `CLAWTROL_API_TOKEN`/`CLAWTROL_HOOKS_TOKEN` via `Rack::Utils.secure_compare`).
   - Throttles: `api_by_token` 100/60s, `anonymous` 20/60s, `write_operations` 30/60s, `task_creation` 10/60s.
   - 429 JSON response with `X-RateLimit-Retry-After`.
2. **Per-controller (Rails cache sliding window):** `app/controllers/concerns/api/rate_limitable.rb` — `rate_limit!(limit:, window:, key_suffix:)`. Default in `BaseController`: **120 req / 60 s**. Emits `X-RateLimit-{Limit,Remaining,Reset}` and `Retry-After`. Identifier is `user:<id>` or `ip:<ip>`.

### 4.4 Error handling

Two mirrored rescue chains:

| Location | Rescues | Rendered as |
|---|---|---|
| `ApplicationController` | `ActiveRecord::RecordNotFound`, `StaleObjectError`, `ParameterMissing` | HTML 404 / redirect-back / turbo `head` |
| `Api::V1::BaseController` | + `RecordInvalid`, `ArgumentError` | JSON `{ error: ... }` with appropriate status |

Logging of unexpected `ArgumentError` is done in `Api::V1::BaseController#bad_argument` before returning 400.

### 4.5 Security headers & CSP

- `ApplicationController#set_security_headers` (after_action): `X-Content-Type-Options`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, `Permissions-Policy`, `X-Permitted-Cross-Domain-Policies`.
- CSP initializer: `config/initializers/content_security_policy.rb`.
- Parameter filtering: `config/initializers/filter_parameter_logging.rb`.
- SSRF guard concern: `app/controllers/concerns/ssrf_protection.rb`.
- CSRF is enabled on the API base (`include ActionController::RequestForgeryProtection`) to support cookie-auth'd browser calls.
- Validation-command safety: `app/models/concerns/validation_command_safety.rb` + `Task::ALLOWED_VALIDATION_PREFIXES` + `UNSAFE_COMMAND_PATTERN` reject any user-provided command containing shell metacharacters.

### 4.6 Host authorization (`config/environments/production.rb`)

Explicit allow-list: `clawdeck.io` (+ subdomains), `app.clawdeck.io`, `clawdeck.onrender.com`, `view.puntofutura.com.ar` (+ subdomains), `127.0.0.1`, `::1`, plus `APP_BASE_URL` host. ActionCable `allowed_request_origins` mirrors this plus the LAN IP `192.168.100.186`.

SSL is intentionally disabled (`assume_ssl = false`, `force_ssl = false`) because the app runs on a local network behind nginx.

---

## 5. Real-time layer

- **Transport:** ActionCable on SolidCable (table `solid_cable_messages`), mounted at `/cable`.
- **Primary broadcasters:** `Task::Broadcasting` (`app/models/task/broadcasting.rb`) emits:
  - `Turbo::StreamsChannel.broadcast_action_to("board_<id>", …)` for `prepend`/`replace`/`remove`/column-count updates (rendering `boards/_task_card` partial).
  - `KanbanChannel.broadcast_refresh` on every create/update/destroy (even when activity_source is "web", so other tabs/devices stay in sync).
  - `TaskUpdatesChannel.broadcast_task_change` for per-user, cross-board notifications.
  - `AgentActivityChannel.broadcast_status` when `agent_session_id`, `status`, or `agent_claimed_at` change.
- **Turbo Streams** are used for the kanban columns and for most config-form partials (`app/views/**/_*.html.erb`).
- **Short-sorted columns:** `in_review` and `done` are re-rendered as whole lists (paged to `Task::KANBAN_PER_COLUMN_ITEMS = 25` with infinite scroll) to preserve deterministic ordering.

---

## 6. Background jobs (`app/jobs/`, 29 jobs)

- **Adapter:** SolidQueue on a dedicated `queue` database (`config/environments/production.rb` → `config.solid_queue.connects_to = { database: { writing: :queue } }`).
- **Base:** `ApplicationJob` (`app/jobs/application_job.rb`) retries `ActiveRecord::Deadlocked` (3x, 5s) and transient network errors (`Net::*Timeout`, `Errno::ECONN*`, 3x polynomial backoff); discards `ActiveJob::DeserializationError`.
- **Scheduled recurring tasks (`config/recurring.yml`):**
  - `agent_auto_runner_tick` — `AgentAutoRunnerJob` every 1 min (demotes expired leases, pings OpenClaw when work exists; **does not** auto-claim — OpenClaw is the sole orchestrator).
  - `process_recurring_tasks` — `ProcessRecurringTasksJob` hourly (clones recurring Task templates).
  - `zerobitch_metrics` — `ZerobitchMetricsJob` every 1 min.
  - `nightshift_runner` — `NightshiftRunnerJob` at 23:00.
  - `nightshift_timeout_sweeper` — hourly.
  - `daily_cost_snapshot` — 02:00.
  - `daily_executive_digest` — 08:00.
  - Production-only: `SolidQueue::Job.clear_finished_in_batches` hourly at :12.
- **Feature jobs:** factory runners (`factory_runner_job.rb`, `factory_runner_v2_job.rb`, `factory_cycle_timeout_job.rb`), zeroclaw (`zeroclaw_dispatch_job.rb`, `zeroclaw_auditor_job.rb`, `zeroclaw_auditor_sweep_job.rb`), pipeline (`pipeline_processor_job.rb`), auto-validation (`run_validation_job.rb`, `auto_validation_job.rb`, `run_debate_job.rb`), transcripts (`transcript_capture_job.rb`, `transcript_retroactive_archive_job.rb`), webhook notifications (`auto_claim_notify_job.rb`, `openclaw_notify_job.rb`), diffs (`generate_diffs_job.rb`), saved-links ingestion (`process_saved_link_job.rb`), catastrophic guardrails (`catastrophic_guardrails_job.rb`, self-rescheduling from `config/initializers/guardrails.rb` if `CLAWDECK_GUARDRAILS_ENABLED=true`), etc.
- **Auto-runner tuning** (`config/initializers/queue_orchestration.rb`): day/night concurrency, cooldowns, per-model/per-provider inflight caps — all via `AUTO_RUNNER_*` env vars exposed on `Rails.application.config.x.auto_runner`.

---

## 7. Services, presenters, helpers

- **`app/services/` (~85 files)** — workflow-level logic reached for when a controller/model would otherwise bloat. Notable clusters:
  - `app/services/pipeline/` — `orchestrator.rb`, `triage_service.rb`, `auto_review_service.rb`, `context_compiler_service.rb`, `qdrant_client.rb`, `claw_router_service.rb` (task triage/auto-review pipeline).
  - `app/services/zeroclaw/` — auditor stack (`auditor_service.rb`, `auditor_sweep_service.rb`, `auditable_task.rb`, `checklist_loader.rb`, `auditor_config.rb`).
  - `app/services/zerobitch/` — dockerized agent fleet (`docker_service.rb`, `agent_registry.rb`, `auto_scaler.rb`, `fleet_templates.rb`, `memory_browser.rb`, `metrics_store.rb`, `task_history.rb`, `config_generator.rb`).
  - Integration clients: `openclaw_gateway_client.rb`, `openclaw_webhook_service.rb`, `openclaw_models_service.rb`, `openclaw_memory_search_health_service.rb`.
  - Domain services: `bulk_task_service.rb`, `task_import_service.rb`, `task_export_service.rb`, `task_followup_service.rb`, `task_outcome_service.rb`, `validation_runner_service.rb`, `validation_suggestion_service.rb`, `debate_review_service.rb`, `ai_suggestion_service.rb`, `auto_tagger_service.rb`, `factory_engine_service.rb`, `factory_prompt_compiler.rb`, `nightshift_engine_service.rb`, `persona_generator_service.rb`, `session_resolver_service.rb`, `agent_log_service.rb`, `transcript_parser.rb`, `transcript_archive_service.rb`, `transcript_watcher.rb`, `external_notification_service.rb`, `origin_delivery_service.rb`, `origin_routing_service.rb`, `telegram_init_data_validator.rb`, `roadmap_executor_sync_service.rb`, …
- **`app/presenters/`** — only two (`budget_presenter.rb`, `cost_analytics_presenter.rb`) for `/analytics`.
- **`app/serializers/`** — only `task_serializer.rb`. All other API responses are hand-rolled hashes.
- **`app/helpers/`** — 10 view helpers (application, navigation, diff, markdown sanitization, swarm, channel-accounts, cronjobs, identity-links, agent-config, agent-personas).
- **`app/views/layouts/`** — 5 layouts: `application.html.erb` (default), `admin.html.erb`, `auth.html.erb`, `home.html.erb`, `mailer.text.erb` + partials `_agent_terminal.html.erb`, `_mobile_bottom_nav.html.erb`.

---

## 8. Key architectural constraints

- **OpenClaw is the sole orchestrator.** `config/recurring.yml` explicitly states: *"ClawTrol must never auto-claim/promote tasks."* `AgentAutoRunnerJob` only demotes expired leases, notifies zombies, and wakes OpenClaw when runnable work exists.
- **Mission Control routing.** Tasks default `origin_chat_id`/`origin_thread_id` to the user's Telegram chat + `ExternalNotificationService::DEFAULT_MISSION_CONTROL_THREAD_ID` so agent output lands in the group thread, not DMs.
- **Validation-command allow-list.** User-authored validation commands are constrained to `bin/rails`, `bundle exec`, `npm`, `yarn`, `make`, `pytest`, `rspec`, `ruby`, `node`, `bash bin/`, `sh bin/`, `./bin/` prefixes and must not contain shell metacharacters.
- **Strict-loading everywhere.** `Task` and `Board` both declare `strict_loading :n_plus_one` to surface N+1 issues during development.
- **Optimistic locking on tasks.** `ActiveRecord::StaleObjectError` is rescued globally and returned as `409 Conflict` (API) or a flash+redirect_back (HTML).
- **Multi-database.** Production splits into `primary` and `queue` databases (SolidQueue) plus SolidCable/SolidCache stores.

---
