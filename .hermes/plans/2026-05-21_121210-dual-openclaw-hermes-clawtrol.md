# Dual OpenClaw + Hermes ClawTrol Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Preserve ClawTrol's current OpenClaw support while adding Hermes as a first-class backend selectable per user/environment.

**Architecture:** Introduce a platform-neutral `AgentPlatform` layer with adapters for OpenClaw and Hermes. Keep existing Rails UI/controllers mostly intact, but route CLI, gateway, cron, sessions, models, transcripts, and viewer roots through the selected adapter. OpenClaw remains the compatibility/default path until Hermes parity is verified.

**Tech Stack:** Rails app in `/home/ggorbalan/clawdeck`, Ruby service objects, existing OpenClaw `/tools/invoke` gateway client, Hermes CLI/config/session/cron interfaces.

---

## Current Context / Evidence

- `app/models/user.rb` currently restricts `ORCHESTRATION_MODES = %w[openclaw_only]`.
- `db/schema.rb` has `users.orchestration_mode`, plus OpenClaw-specific credential columns:
  - `openclaw_gateway_url`
  - `openclaw_gateway_token`
  - `openclaw_hooks_token`
- `app/controllers/concerns/openclaw_cli_runnable.rb` hardcodes `openclaw` CLI and `~/.openclaw/.env`.
- `app/services/openclaw_gateway_client.rb` assumes OpenClaw Gateway protocol: `POST /tools/invoke` with tools like `sessions_spawn`, `sessions_list`, `cron`, `gateway`.
- `app/controllers/cronjobs_controller.rb` shells out to `openclaw cron ...` directly.
- `app/services/openclaw_models_service.rb` shells out to `openclaw models list --json`.
- `app/controllers/file_viewer_controller.rb` defaults viewer root to `~/.openclaw/workspace`, which caused the Hermes-generated file 404 problem.
- Hermes equivalents exist through CLI and local state:
  - `hermes chat -q`, `hermes sessions list/export`, `hermes cron list/create/edit/pause/resume/run/remove`, `hermes gateway status/start/stop/restart`, `hermes config`, `hermes model`.

---

## Design Decision

Do **not** rename ClawTrol or rip OpenClaw out. Make it a dual-platform control room:

- `openclaw_only`: current behavior, zero regression target.
- `hermes_only`: use Hermes adapters.
- `dual`: show both where possible; default actions route to `preferred_agent_platform`.

Add two concepts:

1. **Platform identity**: `openclaw`, `hermes`.
2. **Capability contracts**: sessions, cron, gateway, models, transcripts, file roots.

---

## Phase 0: Restore Viewer / Deployment Baseline

### Task 0.1: Fix Docker build for ClawDeck

**Objective:** Make the existing app boot before changing architecture.

**Files:**
- Modify: `Dockerfile`
- Test: Docker build / `/up` health check

**Steps:**
1. Add missing native deps for Ruby gems in builder stage, especially `libyaml-dev` for `psych`.
2. Rebuild with `docker compose build web`.
3. Start with `docker compose up -d`.
4. Verify `http://192.168.100.186:4001/up` returns success.
5. Verify viewer link works: `/view?file=research/2026-05-21-x-api-hermes-usage.md`.

**Commit:** `fix: restore clawdeck docker build`

---

## Phase 1: Add Platform Configuration Without Behavior Change

### Task 1.1: Expand user orchestration modes

**Objective:** Allow OpenClaw, Hermes, or dual mode without changing runtime behavior yet.

**Files:**
- Modify: `app/models/user.rb`
- Create migration: `db/migrate/*_add_agent_platform_fields_to_users.rb`
- Test: `test/models/user_test.rb`

**Schema additions:**
- `preferred_agent_platform:string`, default: `openclaw`, null: false
- `hermes_gateway_url:string`
- `hermes_gateway_token:string`
- `hermes_hooks_token:string` (optional future-proofing)
- `hermes_home:string`, default: `~/.hermes`
- `hermes_profile:string`, nullable

**Model changes:**
- `ORCHESTRATION_MODES = %w[openclaw_only hermes_only dual]`
- Add validation for `preferred_agent_platform in %w[openclaw hermes]`.
- Encrypt Hermes token fields if OpenClaw tokens are encrypted in the model.

**Verification:**
- Existing users continue as `openclaw_only` / `openclaw`.
- Existing tests pass.

**Commit:** `feat: add agent platform configuration fields`

---

## Phase 2: Introduce Adapter Interfaces

### Task 2.1: Create platform registry

**Objective:** Centralize adapter lookup and stop controllers from naming OpenClaw directly.

**Files:**
- Create: `app/services/agent_platforms/registry.rb`
- Create: `app/services/agent_platforms/base_adapter.rb`
- Create: `app/services/agent_platforms/result.rb`
- Test: `test/services/agent_platforms/registry_test.rb`

**Interface:**
- `#key`
- `#label`
- `#available?`
- `#health`
- `#sessions_list`
- `#spawn_session!(model:, prompt:)`
- `#session_detail(session_key)`
- `#sessions_send(session_key, message)`
- `#sessions_history(session_key, limit:)`
- `#cron_list(all: true)`
- `#cron_create(params)`
- `#cron_update(id, params)`
- `#cron_delete(id)`
- `#cron_pause(id)` / `#cron_resume(id)` or normalized enable/disable
- `#cron_run(id)`
- `#models_list`
- `#file_roots`

**Verification:**
- Registry returns OpenClaw adapter for current users.
- No controller behavior changed yet.

**Commit:** `refactor: introduce agent platform adapter registry`

### Task 2.2: Wrap existing OpenClaw code in adapter

**Objective:** Preserve current OpenClaw implementation behind the new interface.

**Files:**
- Create: `app/services/agent_platforms/openclaw_adapter.rb`
- Move/wrap logic from:
  - `app/services/openclaw_gateway_client.rb`
  - `app/controllers/concerns/openclaw_cli_runnable.rb`
  - `app/services/openclaw_models_service.rb`
- Test: existing OpenClaw client/model tests plus new adapter tests.

**Rule:** Do not delete old classes immediately. Keep them as wrappers/delegators for one release to reduce risk.

**Verification:**
- `CronjobsController#index` still returns same normalized JSON in OpenClaw mode.
- Existing task spawning still works.

**Commit:** `refactor: route openclaw through platform adapter`

---

## Phase 3: Add Hermes Adapter

### Task 3.1: Add safe Hermes CLI runner

**Objective:** Provide Hermes CLI execution with env/profile/home isolation.

**Files:**
- Create: `app/services/agent_platforms/hermes_cli_runner.rb`
- Test: `test/services/agent_platforms/hermes_cli_runner_test.rb`

**Behavior:**
- Uses `Open3.capture3` with timeout.
- Command defaults to `hermes`, override via `HERMES_CLI_PATH`.
- Env reads `~/.hermes/.env` only if needed and never logs secrets.
- Supports `HERMES_HOME` from user setting.
- Supports `--profile <profile>` when configured.
- Returns `{ stdout:, stderr:, exitstatus: }`.

**Verification:**
- Missing CLI returns structured offline result, not exception.
- Timeout returns structured offline result.

**Commit:** `feat: add hermes cli runner`

### Task 3.2: Implement Hermes cron adapter methods

**Objective:** Normalize Hermes cron operations to ClawTrol cron UI.

**Files:**
- Create: `app/services/agent_platforms/hermes_adapter.rb`
- Modify: `app/controllers/cronjobs_controller.rb`
- Test: `test/services/agent_platforms/hermes_adapter_test.rb`
- Test: `test/controllers/cronjobs_controller_test.rb`

**CLI mapping:**
- List: `hermes cron list --all --json` if supported; otherwise parse stable text or read cron store only through a dedicated parser.
- Create: `hermes cron create <schedule>` plus name/prompt/delivery/model fields as supported.
- Update: `hermes cron edit <id>` or direct supported CLI subcommand.
- Disable: `hermes cron pause <id>`.
- Enable: `hermes cron resume <id>`.
- Run: `hermes cron run <id>`.
- Remove: `hermes cron remove <id>`.

**Normalization:**
Return same job shape currently expected by the frontend:
- `id`
- `name`
- `enabled`
- `schedule`
- `scheduleText`
- `nextRunAt`
- `lastRunAt`
- `lastStatus`
- `payload`
- `delivery`
- `source: hermes`

**Risk note:** Hermes cron CLI may not have JSON for every operation. If missing, prefer adding JSON support upstream in Hermes over brittle screen scraping.

**Commit:** `feat: support hermes cron backend`

### Task 3.3: Implement Hermes sessions adapter methods

**Objective:** Let ClawTrol list and inspect Hermes sessions.

**Files:**
- Modify: `app/services/agent_platforms/hermes_adapter.rb`
- Test: `test/services/agent_platforms/hermes_sessions_test.rb`

**CLI mapping:**
- List: `hermes sessions list --json` if supported; otherwise use Hermes SQLite/session export path through a parser.
- Detail/history: prefer `hermes sessions export <id>` or direct SQLite read via a read-only service.
- Spawn: `hermes chat -q <prompt> --model <model> --source clawtrol-task` for one-shot; for long-running autonomous agents, spawn background process and capture session ID if CLI supports it.
- Send message to running session: only implement if Hermes exposes a supported API/gateway hook; otherwise mark capability as unavailable.

**Normalization:**
- Preserve `session_key` / `session_id` distinction in the UI.
- Add `platform` field to avoid mixing OpenClaw and Hermes IDs.

**Commit:** `feat: support hermes sessions backend`

### Task 3.4: Implement Hermes models/status adapter

**Objective:** Surface configured Hermes provider/model status.

**Files:**
- Modify: `app/services/agent_platforms/hermes_adapter.rb`
- Create: `app/services/hermes_models_service.rb` if model logic grows.
- Test: `test/services/hermes_models_service_test.rb`

**CLI mapping:**
- Current config: `hermes config` or direct config YAML parse.
- Provider/model picker: `hermes model` is interactive; do not call it from Rails. Read config and expose configured model first.
- Full model catalogs can be deferred.

**Commit:** `feat: expose hermes model status`

---

## Phase 4: Dual Mode UI and Routing

### Task 4.1: Platform selector in settings

**Objective:** Let the operator choose OpenClaw, Hermes, or dual.

**Files:**
- Modify relevant config/settings controller/views.
- Test: controller/model tests.

**UI fields:**
- Orchestration mode: OpenClaw only / Hermes only / Dual.
- Preferred action backend in dual: OpenClaw / Hermes.
- Hermes home/profile fields.
- Gateway URL/token fields only if Hermes gateway HTTP API is actually available.

**Commit:** `feat: add agent platform settings UI`

### Task 4.2: Add platform badges and filters

**Objective:** Avoid user confusion when both platforms are enabled.

**Files:**
- Modify sessions, cron, task-agent panels.
- Test: view/component tests where present.

**Behavior:**
- Show badges: `OpenClaw` / `Hermes`.
- In dual mode, list both backends in separate groups first; merge later only after normalized IDs are proven safe.
- Destructive actions require platform-specific route params: `platform=openclaw|hermes`.

**Commit:** `feat: show platform-aware sessions and cron`

### Task 4.3: Route task spawning through selected adapter

**Objective:** Make task execution backend-selectable without breaking OpenClaw.

**Files likely involved:**
- `app/models/task/agent_integration.rb`
- `app/services/agent_auto_runner_service.rb`
- `app/services/agent_completion_service.rb`
- `app/controllers/api/v1/tasks_controller.rb`
- `app/services/openclaw_gateway_client.rb` wrapper or replacement

**Data addition:**
- Add `tasks.agent_platform:string`, nullable/default from user preferred platform.

**Behavior:**
- Existing tasks with no `agent_platform` are treated as `openclaw`.
- New task runs use `current_user.preferred_agent_platform` unless explicitly overridden.
- Store `agent_session_id` with platform namespace in views/logs.

**Commit:** `feat: make task agent backend selectable`

---

## Phase 5: Viewer Roots and Artifact Links

### Task 5.1: Make file viewer multi-root and platform-aware

**Objective:** Stop 404s when Hermes writes artifacts outside OpenClaw workspace.

**Files:**
- Modify: `app/controllers/file_viewer_controller.rb`
- Test: `test/controllers/view_file_security_test.rb`

**Roots:**
- OpenClaw workspace: `~/.openclaw/workspace`
- Hermes workspace default: configurable via `HERMES_WORKSPACE_DIR`, likely `/home/ggorbalan/workspace` or selected project root.
- ClawDeck project: `~/clawdeck`
- Reports dir: `~/nightshift-reports`

**Security:**
- Keep dotfile/dotdir rejection.
- Keep traversal rejection.
- Keep symlink escape checks.
- Add explicit logical prefixes to avoid ambiguity:
  - `openclaw/<path>`
  - `hermes/<path>`
  - `reports/<path>`
  - `clawdeck/<path>`
- Maintain backward compatibility: bare `research/foo.md` resolves to OpenClaw workspace first.

**Commit:** `fix: support hermes artifact roots in viewer`

---

## Phase 6: Tests, Deployment, and Cutover

### Task 6.1: Add adapter contract tests

**Objective:** Ensure OpenClaw and Hermes adapters return compatible shapes.

**Files:**
- Create: `test/services/agent_platforms/adapter_contract_test.rb`

**Coverage:**
- Offline behavior.
- Timeout behavior.
- Cron normalization.
- Session normalization.
- Model/status normalization.

**Commit:** `test: add agent platform adapter contract tests`

### Task 6.2: Run targeted test suite

**Commands:**
- `bin/rails test test/services/agent_platforms`
- `bin/rails test test/controllers/cronjobs_controller_test.rb`
- `bin/rails test test/controllers/view_file_security_test.rb`
- `bin/rails test test/services/openclaw_gateway_client_test.rb`
- `bin/rails test test/services/openclaw_models_service_test.rb`

**Expected:** all pass.

### Task 6.3: Run full Rails tests

**Command:**
- `bin/rails test`

**Expected:** full suite passes or only known unrelated failures documented.

### Task 6.4: Manual smoke test on LAN

**Checks:**
- `/up` healthy.
- `/view?file=openclaw/research/2026-05-21-x-api-hermes-usage.md` works.
- `/view?file=hermes/research/...` works for Hermes-generated artifacts.
- OpenClaw cron list still works in `openclaw_only`.
- Hermes cron list works in `hermes_only`.
- Dual mode shows both with badges.
- Existing task run can still spawn OpenClaw agent.
- Hermes task run can spawn or clearly reports unsupported live-session capability.

---

## Risks / Tradeoffs

- **Hermes CLI JSON support:** If Hermes commands lack JSON flags, add/verify JSON output in Hermes rather than parsing human text.
- **Live session control:** OpenClaw has `/tools/invoke` and `/hooks/agent`; Hermes may not expose identical live session send semantics. Treat this as capability-gated, not forced parity.
- **ID collisions:** OpenClaw and Hermes session/cron IDs must always be stored with platform namespace.
- **Credential naming:** Avoid leaking or logging tokens. Hermes config primarily lives in `~/.hermes/config.yaml` and `.env`; do not duplicate secrets unless needed.
- **Viewer security:** Adding roots increases attack surface. Tests must cover traversal, dotfiles, symlinks, binary downloads, and root-prefix ambiguity.

---

## Effort Estimate

- **Baseline viewer/Docker restore:** 0.5 day.
- **Adapter skeleton + OpenClaw wrapping:** 1–1.5 days.
- **Hermes cron/session/model adapter:** 2–3 days depending on JSON support.
- **Dual UI + task routing:** 1.5–2 days.
- **Viewer roots + tests + hardening:** 0.5–1 day.

**Total realistic:** 5–8 working days for a safe dual-backend ClawTrol.

**Fast MVP:** 2–3 days if limited to viewer fix + Hermes cron/session read-only + OpenClaw untouched as execution backend.

---

## Recommended Implementation Order

1. Restore Docker/viewer first.
2. Add platform fields and registry.
3. Wrap OpenClaw adapter with no behavior change.
4. Add Hermes read-only: health, config/model, sessions list, cron list.
5. Add Hermes cron actions.
6. Add Hermes task spawning only after read-only surfaces are stable.
7. Add dual UI polish.

This preserves OpenClaw while progressively making Hermes real instead of doing a risky big-bang rewrite.
