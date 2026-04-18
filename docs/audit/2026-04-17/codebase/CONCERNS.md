# ClawTrol — Codebase Concerns

**Date:** 2026-04-17
**Auditor:** gsd-codebase-mapper (focus=concerns)
**Target:** `/home/ggorbalan/clawdeck/` (Rails 8.1 kanban for AI agents)
**Methodology:** Static audit via SSH. Evidence cited as `path:line`.
**Severity scale:** P0 crash/compromise - P1 serious - P2 notable - P3 cleanup.

> The owner acknowledges this is a "vibe-coded" project by a non-developer. Production is currently crash-looping. This audit is **severe on purpose**.

---

## 1. KNOWN BUGS (P0)

### 1.1 [P0] Systemd crash-loop — PIDFile mismatch with `puma -d`
- **Symptom:** Production systemd unit crash-loops; service never reaches steady state (per handoff).
- **Root cause:** Unit declares a `PIDFile=` but `puma -d` (daemon mode) forks and writes a PID to a different location; systemd reaps the parent, loops. Likely combined with `Type=simple` or `Type=forking` misalignment.
- **Fix direction:** switch to `Type=simple` + foreground puma (no `-d`); or `Type=notify` with `sd_notify`; remove `PIDFile=` or align it with puma's actual pidfile.
- **Evidence:** handoff note; `config/puma.rb` does not set an explicit `pidfile`/`daemonize` (uses defaults).
- **Impact:** service is **DOWN**. Everything else is secondary.

### 1.2 [P0] Inconsistent authentication on hooks endpoint
- `app/controllers/api/v1/hooks_controller.rb:498` — literal comment: `# BUG FIX: never fall back to User.first — that would attribute limits to wrong user`. Previous code path attributed rate-limit counters to `User.first` when user lookup failed; the fix is in place but the comment confirms a class of silent misattribution bugs already slipped through.
- `app/controllers/api/v1/nightshift_controller.rb:9-10` — `skip_before_action :authenticate_api_token, only: [:report_execution, :sync_crons, :sync_tonight]` then re-gates with `authenticate_hook_token!`. If `HOOKS_TOKEN` env is missing (see 2.3), these endpoints effectively unauthenticated.

### 1.3 [P0] Literal BUG tag left in code
- `app/controllers/api/v1/hooks_controller.rb:498` — explicit `BUG FIX` comment marks a known fragile attribution path.

---

## 2. SECURITY (P0 / P1)

### 2.1 [P0] Hardcoded `SECRET_KEY_BASE` in systemd unit (per handoff)
Per the handoff, the systemd unit embeds `SECRET_KEY_BASE` inline instead of reading `Rails.application.credentials` or a secrets file. Anyone with read on the unit reads the Rails session-signing key — full session forgery.
- **Evidence:** `grep Rails.application.credentials` inside `app/` + `config/` returned **zero** hits. The codebase is not using Rails encrypted credentials at all.
- **Fix:** move to `/etc/clawtrol/env` (mode 0600) referenced via `EnvironmentFile=`.

### 2.2 [P0] `DATABASE_URL` with `postgres:postgres` (per handoff)
Default Postgres superuser + default password in the DB URL. Lateral-movement grade issue on shared infra.

### 2.3 [P0] Missing `HOOKS_TOKEN` env — unauthenticated hook ingress risk
- `config/initializers/rack_attack.rb:22-24` treats `ENV["CLAWTROL_API_TOKEN"]` and `ENV["CLAWTROL_HOOKS_TOKEN"]` as trusted if present; if **both unset**, the safelist accepts `nil` tokens depending on compare semantics. Combined with `req.env["REMOTE_ADDR"].nil?` safelist at `rack_attack.rb:15` (any proxy misconfig that strips remote addr -> rate-limit bypass).
- `app/controllers/api/v1/hooks_controller.rb` rate-limits at 30/60s via `before_action`, but the auth gate `authenticate_hook_token!` hinges on an env var that per handoff is **unset in production**.

### 2.4 [P1] Rack::Attack whitelists entire `/24` LAN
- `config/initializers/rack_attack.rb:17` — `req.env["REMOTE_ADDR"].start_with?("192.168.100.")` safelists **every host** on the LAN. Any compromised LAN device (printer, IoT) bypasses ALL rate limiting. This is a blast-radius amplifier.

### 2.5 [P1] `html_safe` on server-rendered HTML passed through controllers
- `app/controllers/showcases_controller.rb:37` — `render html: content.html_safe, layout: false` (agent-generated HTML).
- `app/controllers/previews_controller.rb:59` — same pattern (agent-generated HTML).
- `app/controllers/marketing_controller.rb:220,229` — `html_safe` on rendered content.
- `app/controllers/boards_controller.rb:125,159` — `html.html_safe`.
- `app/views/marketing/index.html.erb:78,109` — `join.html_safe` on tree-rendered nodes with unsanitized children.
- **Risk:** any user-controlled content leaking into these paths -> stored XSS. Comments claim "sandboxed iframe" or "server-rendered from ERB partials" — these assumptions are not enforced by type. One upstream change drops the sandbox and XSS is live.

### 2.6 [P1] Shellouts via `system("bash", "-lc", ...)` in a job
- `app/jobs/factory_runner_v2_job.rb:221,225,232` — three `system("bash", "-lc", "cd <workspace> && git ...")` calls. `Shellwords.escape` is used on the workspace path, **good**, but running user-workspace git operations as the Rails user grants whatever FS/network access the Rails process has. If the workspace contains a malicious git hook (`.git/hooks/post-commit`), it executes on commit under the Rails UID.
- **Fix:** run with `GIT_CONFIG_GLOBAL=/dev/null` and `core.hooksPath=/dev/null`, or sandbox with bubblewrap/firejail.

### 2.7 [P1] `Object#send` used to bypass private methods
- `app/services/factory_github_service.rb:66` — `@loop.send(:configure_workspace_hooks!)`.
- `app/controllers/memory_dashboard_controller.rb:124` — `gateway_client.send(:post_json!, ...)`.
- `app/models/token_usage.rb:174` — `self.class.send(:normalize_model_name, ...)`.
- Reaching through `send` into private API is a maintenance landmine; also couples public behaviour to implementation details.

### 2.8 [P1] Dynamic `public_send` on user-influenceable attributes
- `app/jobs/factory_runner_v2_job.rb:206` — `agent.public_send(attr)` where `attr` originates from config.
- `app/services/origin_routing_service.rb:17-19` — `task.public_send(key)` / `task.public_send("#{key}=", value)` with `key` from routing config. If routing config is user-editable this is a **mass-assignment bypass**.
- **Verify:** confirm `key` source. If user-editable -> P0.

### 2.9 [P2] `.env` file exists on disk (not inspected)
- `.env` exists at `/home/ggorbalan/clawdeck/.env` (393 bytes, mode 664). Not inspected per audit rules. Verify `.gitignore` covers it and that it is not in the repo history.

### 2.10 [P1] No row-level authorization (per handoff)
Controllers check `require_authentication` (session) but do not scope AR queries to `current_user.id`. Any authenticated user can likely read/modify other users' boards/tasks by guessing IDs. Not proven in this audit but listed as a known gap by the owner — treat as **P1 until proven otherwise**.

### 2.11 [P2] No Brakeman run recorded
- `config/brakeman.ignore` exists -> Brakeman was wired up at some point.
- No evidence of recent run (no `tmp/brakeman*`, no CI output visible). Run `bundle exec brakeman -A` as a standing baseline.

---

## 3. TECH DEBT (P1 / P2)

### 3.1 [P1] God-files — maintenance hazard

| Lines | File |
|---|---|
| 1148 | `app/views/boards/tasks/_panel.html.erb` |
| 1038 | `app/controllers/api/v1/tasks_controller.rb` |
| 757  | `app/controllers/zerobitch_controller.rb` |
| 602  | `app/views/telegram_mini_app/show.html.erb` |
| 583  | `app/controllers/api/v1/hooks_controller.rb` |
| 575  | `app/views/marketing/playground.html.erb` |
| 561  | `app/controllers/boards/tasks_controller.rb` |
| 517  | `app/controllers/file_viewer_controller.rb` |
| 496  | `app/services/agent_auto_runner_service.rb` |
| 488  | `app/services/openclaw_gateway_client.rb` |

Project standard is <800 lines; three controllers and a partial blow past it. `tasks_controller.rb` at 1038 lines with a 24-action `before_action :set_task` list at line 12 is a refactor red flag.

### 3.2 [P1] Hardcoded IPs / hostnames baked into application code
- `app/jobs/nightshift_runner_job.rb:44` — `http://192.168.100.186:4001/...` (LAN IP in a job template).
- `app/helpers/navigation_helper.rb:72` — nav item URL `http://192.168.100.186:4010`.
- `app/services/zerobitch/auto_scaler.rb:94` — `http://localhost:4001/...`.
- `app/services/agent_auto_runner_service.rb:109` — fallback `http://192.168.100.186:18789`.
- `app/controllers/webchat_controller.rb:27,30` — `http://localhost:18789` fallback.
- `app/services/pipeline/qdrant_client.rb:9-10` — LAN fallbacks (these use `ENV.fetch` with a default, less bad, but still bake the address).

Any move to a different host / staging box requires touching code. No `STAGING` environment exists (per handoff); this is the compounding factor.

### 3.3 [P2] TODO/FIXME stock is surprisingly low — but one is meaningful
- `app/jobs/run_debate_job.rb:16` — `TODO: When implementing real debate:` — a core feature is stubbed.
- `app/services/zeroclaw/auditor_service.rb:167` — the auditor literally rejects outputs containing `TODO|TBD|fix later|placeholder` (good — explains why source TODOs are rare).
- `app/controllers/api/v1/hooks_controller.rb:498` — `# BUG FIX` marker (see 1.3).

### 3.4 [P2] 167 migrations, no squash
- `db/migrate/` has **167** migrations. Latest timestamps are `20260401*`. Boot cost on fresh DB is non-trivial and each migration is a potential `db:migrate` trap. Consider `db:schema:dump` as the source of truth for new envs, or squash pre-1.0 migrations.

### 3.5 [P3] `Rails.application.credentials` unused
Zero hits across `app/` and `config/`. Secrets management is entirely env-var-based. Not wrong, but means no encrypted secrets rotation path and no `credentials.yml.enc` audit trail.

---

## 4. PERFORMANCE (P2)

### 4.1 [P2] Probable N+1s — lots of `.each do |x|` in views with AR objects
Sample from `app/views` (30 shown of more):
- `app/views/nightbeat/index.html.erb:33,41` — nested `@tasks_by_project.each do |project, tasks| ... tasks.each do |task|` — almost certainly N+1 on task associations.
- `app/views/previews/index.html.erb:35` — `@tasks.each do |task|` — likely N+1 on board/agent.
- `app/views/workflows/index.html.erb:22`, `pipeline_dashboard/show.html.erb:29`, many `zerobitch/*`, `channel_config/*` — need `includes(:association)` audit.
- **Recommendation:** add `Bullet` gem in development/staging to surface these empirically.

### 4.2 [P2] Default Puma threads = 3
- `config/puma.rb:29` — `threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)`. Paired with no worker/fork config visible in the first 30 lines, concurrency ceiling is low. Also interacts with AR pool size (not audited here).

### 4.3 [P2] Webhook logger stores JSON in-row
- `app/models/webhook_log.rb:91,99` — unserialization fallbacks for `headers` / `body`. Without TTL/rotation on `webhook_logs`, table bloats.

---

## 5. FRAGILE AREAS (P1 / P2)

### 5.1 [P1] `tasks_controller#set_task` filter list is a 24-action giant
`app/controllers/api/v1/tasks_controller.rb:12` — one `before_action :set_task, only: [:show, :update, :destroy, :complete, :agent_complete, :claim, :unclaim, :requeue, :assign, :unassign, :generate_followup, :create_followup, :move, :enhance_followup, :handoff, :link_session, :log_event, :report_rate_limit, :revalidate, :start_validation, :run_debate, :complete_review, :recover_output, :dispatch_zeroclaw, :file, :add_dependency, :remove_dependency, :dependencies, :agent_log, :session_health, :run_lobster, :resume_lobster, :spawn_via_gateway]` — any new action will silently be **unfiltered** if the author forgets to add it to this list. Easy to miss in review.

### 5.2 [P2] Many silent `return nil` / `return []` paths in core models
- `app/models/task/agent_integration.rb:175, 249, 254, 289` — integration falls back to `nil` on missing files/heartbeats with no logging.
- `app/models/notification.rb:192, 195, 200` — notifications silently drop on dedup miss.
- `app/models/cost_snapshot.rb:39, 45, 99` — budget math returns nil with no warn.
- `app/jobs/transcript_capture_job.rb:55, 61, 110` — transcript capture silently no-ops when filesystem shape is off.

Silent nils in agent/heartbeat code are especially dangerous: you cannot distinguish "no data yet" from "a code path is broken". **At minimum** log at `:debug`/`:info` on every early return.

### 5.3 [P2] Task recurring logic has multiple guard clauses
`app/models/task/recurring.rb:28, 48, 61` — three returning-nil branches in a single method. If the template is misconfigured you get silence, not an error.

---

## 6. TEST COVERAGE (P1)

- `test/**/*_test.rb` files: **301** (Minitest tradition).
- `spec/**/*.rb` files: **0** (no RSpec).
- **Per handoff, tests are stale.** Not verified; needs a `bin/rails test 2>&1 | tail -40` run.
- **No visible CI wiring** inspected in this pass (no `.github/workflows` checked — recommend follow-up).
- **No coverage tool** detected (`simplecov`, `coverage/.last_run.json`).

**Action:** run full suite, capture pass/fail/skipped counts, and score current coverage before touching anything else.

---

## 7. MISSING CRITICAL INFRASTRUCTURE (P1)

### 7.1 [P1] No error tracking
- `grep "Sentry\|sentry"` across `config/` + `Gemfile` returned **zero hits**. No Sentry, no Honeybadger, no Rollbar. Production errors go to Rails log only. For a crash-looping service this is the difference between "we know" and "we guess".

### 7.2 [P1] No staging environment
Per handoff. All IP/host deltas (see 3.2) make a staging cutover painful until those are fully env-var-driven.

### 7.3 [P1] No rate limit on agent spawn
Spawn endpoints under `api/v1/tasks_controller.rb` (`:spawn_via_gateway`) inherit only the default **120 req/min per user** from `base_controller.rb:14`. An agent spawn is expensive (spawns subprocesses, hits gateway, burns tokens). 120/min per user is way too generous. Add a per-endpoint, per-user `rate_limit!` at `:spawn_via_gateway` — e.g. 5/min.

### 7.4 [P2] No uptime monitoring / health-check contract
A `health_controller.rb` exists — not audited for what it returns. Systemd PIDFile bug (1.1) suggests nobody is watching a simple `curl /up` every minute with an alert.

### 7.5 [P2] No structured logging
`webhook_log.rb` aside, log statements are `Rails.logger.warn(...)` with ad-hoc prefixes. Centralize with a tagged logger and ship to Loki/Elastic before the next incident.

---

## 8. SCALING LIMITS (P2)

1. **Single Puma, 3 threads default** (4.2) — ceiling is ~3 concurrent requests per worker. With no `workers` directive shown, this is **3 total**.
2. **SQLite vs Postgres not verified.** Handoff says postgres; confirm via `config/database.yml` and connection pool sizing.
3. **`webhook_logs` / `cost_snapshots` / `background_runs` retention** — no visible pruning jobs.
4. **Agent transcripts on local filesystem** — `app/jobs/transcript_capture_job.rb` reads from `SESSIONS_DIR`. Single-host bound; no S3/blob abstraction.

---

## 9. TOP 5 CONCERNS BY SEVERITY

1. **P0 — systemd crash-loop** (1.1). Service down.
2. **P0 — hardcoded `SECRET_KEY_BASE` + `postgres:postgres` DATABASE_URL in systemd unit** (2.1, 2.2). Session forgery + DB takeover.
3. **P0 — unauthenticated hook ingress if `HOOKS_TOKEN` unset** (2.3) combined with LAN-wide rack-attack safelist (2.4).
4. **P1 — no error tracking, no staging, stale tests** (6, 7.1, 7.2). You cannot safely fix anything above without these.
5. **P1 — god-files + 24-action `before_action :set_task` list** (3.1, 5.1). Refactor target before further feature work; every change here risks a silent unfiltered endpoint.

---

## 10. RECOMMENDED IMMEDIATE SEQUENCE

1. **Stop the bleed:** fix systemd unit (remove `-d`, align PID file) -> service stays up.
2. **Rotate & relocate secrets:** new `SECRET_KEY_BASE`, non-superuser DB role, move to `EnvironmentFile=/etc/clawtrol/env` (0600).
3. **Verify hook auth:** set `CLAWTROL_HOOKS_TOKEN`, add a test that `/api/v1/hooks/*` returns 401 without it.
4. **Tighten rack-attack safelist:** drop the `192.168.100.*` CIDR, rely on `X-Internal-Request` + token.
5. **Add Sentry**, wire `config/initializers/sentry.rb`, point DSN via env var.
6. **Run the test suite + Brakeman**, capture baseline, fix red.
7. **Then** — row-level authz audit (every AR `.find` -> `.where(user: current_user).find`).

---

*Generated by gsd-codebase-mapper. Citations are `path:line`. No secrets or credentials were read.*
