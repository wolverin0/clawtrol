# ClawTrol — Pre-Acquisition Technical Diligence Audit

**Auditor:** senior software architect, no-benefit-of-the-doubt stance
**Methodology:** vibe-code-audit-prompt-v2.1
**Date:** 2026-04-17
**Commit audited:** ea3b0fd (+ 2 uncommitted layout files)
**Target:** https://github.com/wolverin0/clawtrol (branch: audit/2026-04-17)
**Repo on VM:** /home/ggorbalan/clawdeck/
**Runtime state at audit start:** service crash-looping, restart counter = 27, port 4001 refusing connections

---

## Hard Stops

**No H-class conditions found.** The audit ran the full §1.4 checklist:

| # | Condition | Result |
|---|-----------|--------|
| H1 | RLS/row-level access disabled on user-data tables | N/A — Postgres + app-level scoping via `current_user.tasks`. See Domain 1 for gaps. |
| H2 | Admin secret reachable from client | Negative. `SECRET_KEY_BASE` + DB creds live in systemd unit file (server-only). Problem, not H-class — see Domain 4. |
| H3 | Data-mutation endpoint without auth | Negative. All POST/PUT/PATCH/DELETE under `/api/v1/` require bearer token or session cookie (`Api::TokenAuthentication` in `app/controllers/api/v1/base_controller.rb:10`). Three endpoints `skip_before_action :authenticate_api_token` but then apply `authenticate_hook_token!` (`app/controllers/api/v1/nightshift_controller.rb:10`). |
| H4 | .env in git history | Negative. `git log --all --full-history -- .env .env.production` returned empty. `.env` is gitignored; only `.env.production.example` is tracked. |
| H5 | Payment webhooks unsigned | N/A — no payment providers integrated (no Stripe, MercadoPago, PayPal). |
| H6 | User HTML rendered raw | Negative. Marketing raw renders are on static tree (`app/views/marketing/index.html.erb:78,109`). `sanitize()` with tag allowlist on diff rendering (`app/views/boards/tasks/diff_file.html.erb:60`). `html_safe` only on hardcoded SVG strings (`app/helpers/application_helper.rb:39-45`). `MarkdownSanitizationHelper` exists and is used on Redcarpet output. |
| H7 | SQL string-concat with user input | Negative. Sole interpolated-SQL site (`app/controllers/pipeline_dashboard_controller.rb:27`) uses parameterized form `where("tasks.name ILIKE ?", "%#{@query}%")`. Arel.sql interpolation in `app/models/task.rb:123` uses `table_name` (not user input). |
| H8 | Temporary bypass / hardcoded admin backdoor | Negative for literal backdoors. **Near-miss**: `app/controllers/api/v1/pipeline_controller.rb:111` falls back to `User.where(admin: true).first || User.first` when hook-token auth cannot resolve a specific user. Single-operator today; multi-tenant blocker tomorrow. Flagged Critical below. |

**Verdict override:** none from hard stops. Score math stands.

---

## Part A — Founder One-Page Verdict

- **Overall verdict:** **FIX BEFORE LAUNCH**
- **Vibe Debt Score:** **42 / 100** (arithmetic: 2 Critical × 15 + 2 High × 6 + 0 hard-stops × 20 = 42. See §3 Scorecard.)
- **Is customer data at risk right now?** **No — with one caveat.** The app runs on your LAN with no public exposure. Authentication is disciplined (timing-safe token compare, HttpOnly cookies, SameSite=strict). But if you ever expose `/api/v1/pipeline/*` publicly, the "fallback to first admin user" line quietly becomes a privilege-escalation vector.
- **Will it survive its first viral moment (10× traffic)?** **Unknown, leaning no.** The app is currently crash-looping (systemd PID-file mismatch, 27 restarts during audit). Fix that first. You also have Solid Queue in-process with Puma, which is fine for 1 user and painful at 50.
- **Biggest single risk, in one sentence, no jargon:** Your production server is crashing every 20 seconds in a systemd-vs-Puma config bug that stops clients from connecting, even though everything "looks" running.
- **Estimated remediation to production-grade:** **2–4 developer-weeks** (one real engineer, not counting feature work).
- **Can you fix the critical issues yourself with AI assistance?** **Yes for 4 items; No for 2 items** (the multi-tenant auth fallback and the secret rotation choreography need a human eye on blast radius).
- **Top 3 things to fix before anything else:**
  1. Fix the crash loop — systemd `PIDFile` vs. Puma `-d` flag mismatch (see FIX PROMPT #1). Unblocks everything else.
  2. Rotate leaked GitHub OAuth token in `git remote -v` URL, and move `SECRET_KEY_BASE` + DB creds out of the systemd unit file into an `EnvironmentFile=` with `0600` perms (FIX PROMPT #2).
  3. Set `HOOKS_TOKEN` env var in production (currently empty — see `[SECURITY]` banner in systemd logs) and decide what `PipelineController` should do when the token resolves no user (FIX PROMPT #3).

---

## Part B — Executive Summary

ClawTrol is a Rails 8.1 kanban dashboard that looks far more disciplined than its "vibe-coded" self-description implies. The authentication layer is thoughtfully built: timing-safe comparisons, HttpOnly + SameSite=strict cookies, a dedicated hooks-token lane for webhook traffic, per-user scoping on 23/29 API controllers, and a mature Rack::Attack configuration with LAN IP safelisting and per-operation throttles. CI runs Brakeman, bundler-audit, RuboCop, importmap audit, minitest, and system-tests on every push. Most of the "security gaps" flagged in the handoff are actually fixed (commit `74335f7`: command-injection fixed, `ai_api_key` encrypted, API tokens hashed).

The actual problems are operational and architectural debt, not greenfield vulnerabilities. The server is currently crash-looping because `config/puma.rb:45` only writes a PID file if `ENV["PIDFILE"]` is set, but the systemd unit specifies `PIDFile=.../server.pid` without setting that env var — so systemd cannot track the forked Puma, tries to `kill $MAINPID` (empty string), fails, and restart-loops every ~20s. Secrets live in plaintext inside `~/.config/systemd/user/clawtrol.service`. The Pipeline controller has a "first admin user" fallback that will bite when this stops being single-tenant. Nginx config targets a `clawdeck.so` domain that is not the current LAN deployment. One hardcoded VM IP lives in `agent_auto_runner_service.rb` and `navigation_helper.rb`.

**Tool fingerprint (§1.1):** Heavy **Claude Code / Aider** signature with some **Cursor** tells. Evidence: well-structured service objects and concerns, deliberate `frozen_string_literal: true` headers throughout, defensive `MarkdownSanitizationHelper` with guidance comments, but also 1000+-line `tasks_controller.rb` (god-file drift) and inconsistent inheritance (`PipelineController < ActionController::API` vs. `TasksController < BaseController`). Confidence: High.

**Top 5 headline risks:**
1. **Crash loop from puma/systemd PIDFile mismatch** — prod is down right now.
2. **Plaintext secrets in systemd unit** — any process on the VM reads `SECRET_KEY_BASE` via `/proc/*/environ`.
3. **Multi-tenant IDOR trapdoor** in `pipeline_controller.rb:111` (fallback to first admin).
4. **Hardcoded VM IPs** in 4 files — not portable, silent failures if IPs change.
5. **Solid Queue inside Puma** (`config/puma.rb:43`) — works now, breaks silently under load or when Puma restarts.

---

## 1. System Overview

- **Stack:** Ruby 3.3.8 (runtime) vs 3.3.1 (Dockerfile `ARG RUBY_VERSION=3.3.1` — drift), Rails 8.1.0, PostgreSQL 16 (Docker on host port 15432 — *not* in `docker-compose.yml`, which maps default 5432), Puma 7.2, Propshaft asset pipeline, Tailwind CSS v4 via `tailwindcss-rails`, Hotwire (Turbo + Stimulus) no SPA framework, Importmap (no bundler).
- **Background processing:** SolidQueue (database-backed), runs in-process inside Puma via `plugin :solid_queue` (`config/puma.rb:43`).
- **Real-time:** ActionCable via SolidCable (no Redis).
- **Cache:** SolidCache (no Redis).
- **Auth:** Session cookies (custom `Authentication` concern, not Devise) + bearer API tokens (hashed in DB per commit `74335f7`) + `X-Hook-Token` for webhook lane + OmniAuth GitHub OAuth.
- **External integrations (per `.planning/codebase/INTEGRATIONS.md`):** OpenClaw gateway primary (`http://192.168.100.186:18789/tools/invoke`, `/hooks/wake`), GitHub OAuth + `gh` CLI, Telegram Bot API (3 call sites), Z.AI GLM direct chat completions, OpenAI Images direct, Gemini CLI, Qdrant + Ollama RAG stack, n8n webhook, user-defined webhooks, SMTP, Lobster pipeline runner.
- **Note:** `faraday` and `httparty` are in `Gemfile` but **unused** in `app/` — all outbound HTTP is via stdlib `Net::HTTP`. Dead dependencies.
- **Deployment:** Systemd user service on Ubuntu homeserver (192.168.100.186:4001), HTTP only (LAN), PostgreSQL in Docker.
- **Trust boundaries:** Browser ↔ Puma (cookie session); OpenClaw gateway ↔ Puma (`X-Hook-Token` on `/hooks/clawtrol` and nightshift sync routes); Puma ↔ Postgres (local loopback, `postgres:postgres` superuser); Puma ↔ OpenClaw gateway (outbound, bearer token from user).
- **Abandoned work visible in code:** `bf7668f feat: add openclaw sync integrations` followed by `a94d48b refactor: remove dead pipeline code` — mid-refactor of a pipeline feature. See `app/controllers/pipeline_dashboard_controller.rb` + `app/controllers/api/v1/pipeline_controller.rb` + `app/services/pipeline/*.rb`.
- **Unverifiable from repo alone:** actual Postgres user permissions; whether OpenClaw gateway enforces the hooks token on its side; production nginx config (none running — service goes direct to Puma); backup strategy (no evidence in repo).

---

## 2. Repository Inventory

See also `.planning/codebase/` for the gsd-codebase-mapper outputs (STACK, INTEGRATIONS, ARCHITECTURE, STRUCTURE, CONVENTIONS, TESTING, CONCERNS).

**Counts:** 133 controllers, 56 models, 28 jobs, 7 channels, 167 migrations, 301 test files, 29 API v1 controllers (28 inherit from `BaseController`).

**Critical files spot-checked:**
- `Gemfile` (93 lines), `Gemfile.lock` (510 lines)
- `config/routes.rb` (691 lines — single giant file)
- `config/puma.rb:45` (pidfile bug)
- `config/environments/production.rb`
- `config/initializers/rack_attack.rb`, `hooks_token_validation.rb`, `content_security_policy.rb`, `filter_parameter_logging.rb`, `guardrails.rb`
- `~/.config/systemd/user/clawtrol.service`
- `app/controllers/application_controller.rb`
- `app/controllers/api/v1/base_controller.rb`, `tasks_controller.rb`, `pipeline_controller.rb`, `nightshift_controller.rb`, `hooks_controller.rb`
- `app/controllers/concerns/authentication.rb`, `api/token_authentication.rb`, `api/hook_authentication.rb`
- `app/models/task.rb`, `user.rb`, `session.rb`, `api_token.rb`
- `app/jobs/nightshift_runner_job.rb`, `transcript_retroactive_archive_job.rb`
- `app/helpers/markdown_sanitization_helper.rb`, `application_helper.rb`
- `.github/workflows/ci.yml`
- `Dockerfile`, `docker-compose.yml`

---

## 3. Scorecard

| # | Domain | Rating | One-line summary |
|---|--------|--------|------------------|
| 1 | Security | **3/5** | Strong auth primitives; plaintext secrets in systemd unit; multi-tenant fallback is a latent IDOR. |
| 2 | Architecture & Code Quality | **3/5** | God-file `tasks_controller.rb`, inconsistent inheritance on one API controller, otherwise clean Rails idioms. |
| 3 | Database & Data Layer | **3/5** | 167 migrations; DB runs as `postgres` superuser; per-user scoping on Task works. |
| 4 | Infrastructure & DevOps | **1/5** | **Crash-looping right now.** Systemd unit is hostile to Puma defaults. Secrets in plaintext. No monitoring. |
| 5 | Performance | **3/5** | Solid Queue in-process with Puma is a latent bottleneck; no cache layer on analytics. |
| 6 | UI/UX & Accessibility | **3/5** | Not deeply audited; prior "giant black circle on login" bug reveals CSS discipline is fragile. |
| 7 | Reliability & Edge Cases | **2/5** | Rescues present but inconsistent; hardcoded 192.168.100.186 in curl strings. |
| 8 | Legal / Privacy / Compliance | **3/5** | Single-operator, no PII scale, no payments → low exposure. |
| 9 | DX & Maintainability | **3/5** | README + CHANGELOG + CLAUDE.md + handoff doc excellent; test suite health unknown. |
| 10 | Cost & Billing Risk | **3/5** | `max_tokens` caps on 2 service calls; CostSnapshot tracks budgets; no per-user LLM spend caps. |
| 11 | Demo-to-Prod Gap | **2/5** | Hardcoded VM IPs in 4 files; Dockerfile Ruby version drift; nginx config for unused domain. |
| 12 | What's Missing But Expected | **2/5** | No Sentry, no staging env, no structured logging, no backups visible, no API docs. |

**Average:** 2.58 / 5. Skewed down by Infrastructure (1) and Reliability / Demo-to-Prod (2).

**Vibe Debt Score arithmetic:**
- Critical × 15: 2 × 15 = 30
- High × 6:     2 × 6  = 12
- Medium × 2:   counted in Risk Register
- Low × 0.5:    not scored
- Hard stops × 20: 0 × 20 = 0
- **Total: 42 / 100 — "FIX BEFORE LAUNCH"**

---

## 4. Detailed Findings by Domain

### Domain 1: Security — Rating 3/5

▶ **FOUNDER VIEW**
The locks on your front door are well-chosen (strong tokens, proper cookies, rate limits). But the spare house key is taped under the doormat: `SECRET_KEY_BASE` and the database password sit in plaintext inside a file anyone with VM access can read. Plus, one of your API endpoints has a "if I don't know who you are, I'll pretend you're the admin" fallback that you wrote for single-user convenience — dangerous if this ever becomes multi-user.
**FIX URGENCY:** Before launch.

▶ **TECHNICAL EVIDENCE**

- **[CRITICAL] [EXPLOITABLE-LOW-EFFORT] [High] — Plaintext `SECRET_KEY_BASE` and `DATABASE_URL` in systemd unit**
  Evidence: `~/.config/systemd/user/clawtrol.service:8-9` (full 128-char SECRET_KEY_BASE, `postgres:postgres` DB creds)
  Impact: Any process running as `ggorbalan` can read `/proc/PID/environ` of the Rails process and exfiltrate the secret. `SECRET_KEY_BASE` lets an attacker forge signed cookies and session tokens.
  Fix complexity: Small (2–8h).
  Self-serviceable: Yes.

- **[CRITICAL] [EXPLOITABLE-LOW-EFFORT in multi-tenant, BAD-PRACTICE today] [High] — Auth fallback to "first admin user" in PipelineController**
  Evidence: `app/controllers/api/v1/pipeline_controller.rb:111` — `@current_user = User.where(admin: true).first || User.first` when hook token passes but no user claim.
  Impact: Anyone with the `HOOKS_TOKEN` (shared, not per-user) hitting `/api/v1/pipeline/status`, `/task_log`, `/reprocess` etc. sees data for the first admin user and can trigger reprocess on that user's tasks. Currently exploitable only if HOOKS_TOKEN leaks; becomes a full IDOR the moment a second user exists.
  Fix complexity: Small (2–8h).
  Self-serviceable: No — need to define the correct authz model (hook = no-user, hook = explicit user param, hook = reject).
  AI-tool blind spot: B1, B8.

- **[HIGH] [BAD-PRACTICE] [High] — `HOOKS_TOKEN` not set in production**
  Evidence: Systemd log line `[SECURITY] HOOKS_TOKEN environment variable is not set in production!` emitted on every boot (source: `config/initializers/hooks_token_validation.rb`).
  Impact: Webhook endpoints (`/api/v1/hooks/*`, nightshift sync routes) reject all requests because `authenticate_hook_token!` requires non-empty configured token — OpenClaw → ClawTrol callbacks silently fail.
  Fix complexity: Trivial (<2h).
  Self-serviceable: Yes.

- **[HIGH] [BAD-PRACTICE] [High] — Database runs as Postgres superuser**
  Evidence: `~/.config/systemd/user/clawtrol.service:9` — `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:15432/...`
  Impact: SQL injection or ORM escape would have DB-superuser blast radius (DROP, CREATE EXTENSION, COPY FROM PROGRAM, etc.).
  Fix complexity: Small (2–8h) — create role `clawtrol_app` with least-privilege, update DATABASE_URL.
  Self-serviceable: Yes.

- **[MEDIUM] [BAD-PRACTICE] [High] — GitHub OAuth token embedded in git remote URL**
  Evidence: `git remote -v` on VM shows `https://gho_...@github.com/wolverin0/clawtrol.git` for both fetch/push.
  Impact: Token appears in `/proc/*/cmdline` of git invocations and in shell history. Already rotated per user decision.
  Fix complexity: Trivial (<2h). Set remote to tokenless HTTPS + use `gh auth` or SSH key.
  Self-serviceable: Yes.

- **[MEDIUM] [BAD-PRACTICE] [Medium] — `X-INTERNAL-REQUEST` header bypasses rate limits**
  Evidence: `config/initializers/rack_attack.rb:13` — `safelist("internal") { |req| req.env["HTTP_X_INTERNAL_REQUEST"] == "true" || ... }`.
  Impact: Any client can set this header and skip throttling. IP-based LAN safelist is defensible; the header-based one is not.
  Fix complexity: Trivial — remove the header check, keep the LAN IP safelist.

- **[MEDIUM] [UNKNOWN] [Medium] — `config/credentials.yml.enc` present, `config/master.key` absent**
  Evidence: `ls config/master.key` returns "No such file or directory"; `config/credentials.yml.enc` exists.
  Impact: Credentials file cannot be decrypted without the master key. Either the app never reads credentials (all secrets via ENV) or startup silently fails to load them. Unused dead config, remove or restore.

- **[MEDIUM] [BAD-PRACTICE] [High] — `Rails.application.config.app_base_url` default is `localhost`, not asserted in prod**
  Evidence: `config/initializers/app_base_url.rb:2` — `ENV.fetch("APP_BASE_URL", "http://localhost:#{ENV.fetch('PORT', '4001')}")`.
  Impact: Links in emails / redirects silently point to `localhost` if env var is missing.

- **[LOW] Content-Security-Policy initializer exists but not reviewed for inline-script exemptions.** `config/initializers/content_security_policy.rb` — not expanded here, audit separately.

- **[MEDIUM] [BAD-PRACTICE] [High] — Factory loops shell out to `bash -lc` with admin-supplied command strings**
  Evidence: `app/jobs/factory_runner_v2_job.rb:213` — `Open3.capture3(env, "bash", "-lc", command.to_s, chdir: workspace_path.to_s)`. `command` comes from the `FactoryLoop` record's step configuration, set via admin UI.
  Impact: This is by-design (the factory runner exists to execute user-defined improvement commands on a repo workspace), so not an unauthenticated RCE. However: any admin who can configure a FactoryLoop has full shell as the Rails user. In a multi-operator future, this is a privilege-gradient risk.
  Fix complexity: Small — add an allowlist of step "kinds" (`test`, `lint`, `fix`, `commit`) with fixed command templates; reject freeform `command` strings.

- **[LOW] — Rack::Attack response body logged to Rails logger** — probably fine, but includes rate-limit keys (e.g., `write:anon:<ip>`) that leak IPs in logs. Minor.

**What to fix first:**
1. Move secrets to `EnvironmentFile=/etc/clawtrol/clawtrol.env` (chmod 600, root-owned).
2. Set `HOOKS_TOKEN` as env var.
3. Patch `PipelineController#authenticate_user!` fallback (require explicit user param or 401).

**Acquisition concern:** Security posture is B+ for an internal LAN tool, but deploying publicly requires 1–2 engineer-weeks to harden.

[SECTION COMPLETE: Domain 1]

---

### Domain 2: Architecture & Code Quality — Rating 3/5

▶ **FOUNDER VIEW**
The house is tidy overall — rooms labeled, furniture in the right places — but one room (`tasks_controller.rb`) has become a walk-in closet where everything gets dumped. There is also one door (`PipelineController`) built in a different style than every other door in the house. Not broken, just inconsistent.
**FIX URGENCY:** Before scaling past the first engineer hire.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] [BAD-PRACTICE] [High] — God-file: `app/controllers/api/v1/tasks_controller.rb`**
  Evidence: Controller uses `before_action :set_task, only: [...]` with 35+ member actions listed. Includes 5 concerns: `OutputRenderable`, `Api::TaskDependencyManagement`, `Api::TaskPipelineManagement`, `Api::TaskAgentLifecycle`, `Api::TaskValidationManagement`. File >1000 lines.
  Impact: Any change to task lifecycle touches this controller; merge conflicts guaranteed with >1 contributor; slow test boot.
  Fix complexity: Medium (1–3d) — split into REST controller + lifecycle controllers (`tasks/agent_controller`, `tasks/dependencies_controller`) following existing namespace pattern.
  AI-tool blind spot: B9 and Claude-Code over-abstraction.

- **[HIGH] [BAD-PRACTICE] [High] — Inconsistent API base class for `PipelineController`**
  Evidence: `app/controllers/api/v1/pipeline_controller.rb:5` — `class PipelineController < ActionController::API` while all 28 siblings extend `BaseController`.
  Impact: Skips shared `rescue_from` handlers (stale object, argument error, invalid record), shared rate limit `before_action`, `Api::TokenAuthentication`. Reimplements auth locally with the fallback flaw noted in Domain 1.
  Fix complexity: Small (2–8h) — inherit `BaseController`, remove local `authenticate_user!`, add per-action `skip_before_action` for hook-auth endpoints.

- **[MEDIUM] [BAD-PRACTICE] [High] — App module still named `ClawDeck::Application`**
  Evidence: `config/application.rb` — `module ClawDeck`. Rails renders, assets, and deployment are named for clawtrol but the module is not.
  Impact: Confusion when grepping. Minor. Rename during a quiet moment.

- **[MEDIUM] [BAD-PRACTICE] [High] — Unused gems in Gemfile**
  Evidence: `faraday`, `httparty` in `Gemfile:44-46`; no references in `app/**/*.rb`. All HTTP uses stdlib `Net::HTTP`.
  Impact: Attack surface and bundle bloat. Remove.

- **[MEDIUM] [BAD-PRACTICE] [Medium] — Three-layer pipeline feature partially migrated**
  Evidence: `app/controllers/pipeline_dashboard_controller.rb`, `app/controllers/api/v1/pipeline_controller.rb`, `app/services/pipeline/*`. Commit `a94d48b` says "refactor: remove dead pipeline code" but the three layers still coexist.
  Impact: Unclear which pipeline code is authoritative. Maintenance trap.

- **[LOW] 691-line `config/routes.rb`** — split with `draw` files (`config/routes/api.rb`, `config/routes/admin.rb`).

- **[LOW] Rescues inconsistent between `ApplicationController` and `Api::V1::BaseController`.** API controller rescues `ActiveRecord::RecordInvalid`, `StaleObjectError`, `ParameterMissing`, `ArgumentError`. HTML controller does not rescue `RecordInvalid`.

**What to fix first:**
1. Split `tasks_controller.rb`.
2. Align `PipelineController` with `BaseController`.
3. Remove unused `faraday`, `httparty`.

**Acquisition concern:** Overall architecture is salvageable. No rewrite required. Budget 1–2 engineer-weeks for cleanup.

[SECTION COMPLETE: Domain 2]

---

### Domain 3: Database & Data Layer — Rating 3/5

▶ **FOUNDER VIEW**
Your database has grown fast (167 migrations). The tables are organized with proper relationships and per-user ownership, which is good. But the connection string uses the database "superuser" account — like logging into your computer as Administrator to read email. If anything goes wrong in the Rails code, the damage can be much worse than it needs to be.
**FIX URGENCY:** Before first paying customer.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] — DB runs as Postgres superuser** (cross-linked to Domain 1).

- **[MEDIUM] [BAD-PRACTICE] [High] — 167 migrations, no squash, no schema consolidation**
  Evidence: `db/migrate/` contains 167 files, average ~2.5 per dev-day since fork.
  Impact: Slow `db:setup` for new environments; schema drift risk. Rails best practice is to squash annually.
  Fix complexity: Small (2–8h) — `rails runner "DatabaseSchemaCompactor..."` or manual squash to a single `000_baseline.rb`.

- **[MEDIUM] — No visible seed strategy for fixtures vs prod**
  Evidence: `db/seeds.rb` + `db/seeds/` dir present but not reviewed in depth. For acquirer, confirm whether `rails db:seed` is production-safe.

- **[MEDIUM] [BAD-PRACTICE] [Medium] — Interpolated SQL string in HAVING**
  Evidence: `app/jobs/transcript_retroactive_archive_job.rb:50` — `.having("COUNT(agent_activity_events.id) > #{POLLUTION_THRESHOLD}")` (interpolates a constant, not user input).
  Impact: Not exploitable (constant), but normalizes bad pattern; next contributor copies it with user input.
  Fix: `.having("COUNT(agent_activity_events.id) > ?", POLLUTION_THRESHOLD)`.

- **[LOW] — `Session` model uses `strict_loading :n_plus_one`** — good defensive posture, credit where due.

- **[UNVERIFIED — needs DB access] — No visible row-level or application-level audit trail on destructive actions.** `Task.destroy` dependent cascades are defined on 16+ associations but there is no `audit_trail` gem or explicit soft-delete pattern for tasks.

**What to fix first:** Downgrade DB role. Squash migrations. Remove `#{}` interpolation from HAVING.

[SECTION COMPLETE: Domain 3]

---

### Domain 4: Infrastructure & DevOps — Rating 1/5

▶ **FOUNDER VIEW**
This is where the wheels are actively falling off. Your production server has been silently crash-looping during this audit — restarting every 20 seconds because of a config mismatch between the process manager and the web server. The monitoring story is "watch journalctl and hope." No staging environment exists. Secrets are in the service file in plaintext. This is the fix-first domain.
**FIX URGENCY:** Right now (today).

▶ **TECHNICAL EVIDENCE**

- **[CRITICAL] [EXPLOITABLE-NOW — DoS via absence] [High] — Puma/systemd PIDFile mismatch causes crash loop**
  Evidence:
  - `~/.config/systemd/user/clawtrol.service`: `Type=forking`, `ExecStart=... rails server -b 0.0.0.0 -p 4001 -d`, `PIDFile=/home/ggorbalan/clawdeck/tmp/pids/server.pid`, `ExecStop=/bin/kill -QUIT $MAINPID`
  - `config/puma.rb:45`: `pidfile ENV["PIDFILE"] if ENV["PIDFILE"]` — only writes pidfile if env var is set
  - Systemd unit does not set `PIDFILE=`, so Puma daemonizes without writing a pidfile
  - Journalctl: `Can't open PID file /home/ggorbalan/clawdeck/tmp/pids/server.pid (yet?) after start: No such file or directory` followed by `Referenced but unset environment variable evaluates to an empty string: MAINPID` and `clawtrol.service: Control process exited, code=exited, status=1/FAILURE`
  - Restart counter at 27 during audit.
  Impact: The app appears to boot ("Rails 8.1.0 application starting in production"), then systemd declares failure ~5s later and restarts. Port 4001 is bound intermittently at best; clients see "Connection refused". OpenClaw → ClawTrol callbacks fail.
  Fix complexity: Trivial (<2h).
  Self-serviceable: Yes. See FIX PROMPT #1.

- **[CRITICAL] — Plaintext secrets in systemd unit file** (cross-linked to Domain 1).

- **[HIGH] [BAD-PRACTICE] [High] — No error tracking / APM**
  Evidence: No `sentry-ruby`, `honeybadger`, `skylight`, `newrelic_rpm` in Gemfile. Only `Rails.logger` usage.
  Impact: Silent errors in background jobs go unnoticed; no production performance visibility.
  Fix: Add Sentry free tier (5k events/mo) or self-hosted GlitchTip.

- **[HIGH] [BAD-PRACTICE] [High] — No staging environment**
  Evidence: `config/environments/` has `development.rb`, `production.rb`, `test.rb` only. No staging. Runbook in handoff confirms only one environment.
  Impact: Schema migrations, feature flags, new gems ship direct-to-prod.
  Fix: `config/environments/staging.rb` cloned from prod + a second systemd unit on a second port.

- **[MEDIUM] [BAD-PRACTICE] [High] — Dockerfile Ruby version drift**
  Evidence: `Dockerfile:5` — `ARG RUBY_VERSION=3.3.1`, runtime uses 3.3.8 (via rbenv).
  Impact: Container-based prod rollout would hit gem compile differences vs. local runtime.

- **[MEDIUM] [BAD-PRACTICE] [High] — Nginx config targets unused domain**
  Evidence: `config/nginx/*.conf` configures `server_name clawdeck.so www.clawdeck.so` with Let's Encrypt cert paths that do not exist on the VM.
  Impact: Dead-config confusion. Operator has no way to tell which is the live deployment.

- **[MEDIUM] [BAD-PRACTICE] [High] — No centralized log aggregation or rotation**
  Evidence: `config/logrotate/` directory exists (not fully read); `RAILS_LOG_TO_STDOUT=true` sends to journalctl. No remote log shipping.
  Impact: Logs are only queryable via `journalctl --user -u clawtrol -f`, gone on host reinstall.

- **[LOW] — `ExecStop=/bin/kill -QUIT $MAINPID`** fails even when PIDFile is set correctly because `Type=forking` only populates MAINPID after successful PIDFile read. Use `Type=simple` or `Type=notify` + drop `-d`.

**What to fix first:** FIX PROMPT #1 (pidfile + service type). That unblocks everything.

[SECTION COMPLETE: Domain 4]

---

### Domain 5: Performance — Rating 3/5

▶ **FOUNDER VIEW**
It works fine today for one user. At 10 users it will feel slow in places. At 100 users, some pages will time out. Biggest bottleneck is that your background-job processor runs inside the same process as your web server — a design that is easy to set up but hard to scale.
**FIX URGENCY:** Before scaling.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] [BAD-PRACTICE] [High] — SolidQueue runs inside Puma**
  Evidence: `config/puma.rb:43` — `plugin :solid_queue`. Puma config says 3 threads / 1 worker default.
  Impact: When Puma restarts (asset precompile, crash loop), jobs stall. Under load, web requests and jobs compete for the same GVL. Standard for single-user hobby apps; problematic beyond.
  Fix: Move SolidQueue to its own systemd service (`rails solid_queue:start`) once traffic warrants it.

- **[MEDIUM] — `Task.includes(TASK_JSON_INCLUDES)` pattern in controllers**
  Evidence: `app/controllers/api/v1/tasks_controller.rb:138,161,470` — preloads present, good. Unverified if `TASK_JSON_INCLUDES` is exhaustive; `bullet` gem only runs in dev/test.
  Impact: Undetected N+1s possible in production.
  Fix: Add `bullet` to production with raise-mode off, logging-only.

- **[MEDIUM] — No cache layer on analytics endpoints**
  Evidence: `app/controllers/api/v1/analytics_controller.rb` presumably ChartKick-backed; `chartkick` + `groupdate` are in Gemfile.
  Impact: Aggregation queries re-run per request.
  Fix: `Rails.cache.fetch("token_usage_#{current_user.id}", expires_in: 5.minutes) { ... }` (SolidCache already wired).

- **[LOW] — Session uses `strict_loading :n_plus_one`** — credit.

[SECTION COMPLETE: Domain 5]

---

### Domain 6: UI/UX & Accessibility — Rating 3/5

▶ **FOUNDER VIEW**
Cannot deep-audit UI/UX from code alone (no running UI available during audit, server is crash-looping). What we can infer: Hotwire + Tailwind is a modern, accessible foundation. The prior "giant black circle on login" incident (handoff §8) shows that asset-pipeline discipline has been fragile.
**FIX URGENCY:** When convenient, plus one fix before launch.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] [UNVERIFIED] [Medium] — Uncommitted layout fixes on main branch**
  Evidence: `git diff app/views/layouts/application.html.erb app/views/layouts/auth.html.erb` shows +1 line each — the Tailwind stylesheet tag added on 2026-04-15 per handoff. Not committed.
  Impact: Next `git reset --hard` or fresh clone loses the fix. Re-introduces the "giant black circle" regression.
  Fix complexity: Trivial. Commit to `audit/2026-04-17` immediately.

- **[MEDIUM] [INFERRED] — No visible a11y testing**
  Evidence: No `axe-core`, no `@axe-core/puppeteer`, no capybara-a11y gem. Manual a11y only.
  Impact: Screen-reader support unknown. If launched to any public audience including corporate / EU, legal risk (ADA / EAA).

- **[MEDIUM] [UNVERIFIED] — Multiple theme variants without documented switching**
  Evidence: Handoff lists themes `dark, synthwave, nord, dracula, vaporwave`. User model has `theme` column. CSS variable switching not fully audited.

- **[LOW] — Custom fonts from fontshare.com (Clash Display, Satoshi)** — confirm license for commercial use before public launch.

**What to fix first:** Commit the Tailwind-link layout fix.

[SECTION COMPLETE: Domain 6]

---

### Domain 7: Reliability & Edge Cases — Rating 2/5

▶ **FOUNDER VIEW**
Most of the code has proper error handlers. But there are enough hardcoded assumptions (specific IP addresses, specific port numbers, specific user counts) that if any one of them moves, parts of the app silently stop working without telling you.
**FIX URGENCY:** Before scaling or moving hosts.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] [BAD-PRACTICE] [High] — Hardcoded VM IP in 4+ production code paths**
  Evidence:
  - `app/jobs/nightshift_runner_job.rb:44-50` — curl string and `uri = URI.parse("#{user.openclaw_gateway_url}/hooks/wake")` (actually user-configurable — OK; but adjacent curl literal has the hardcode)
  - `app/helpers/navigation_helper.rb:72` — `url: "http://192.168.100.186:4010"` (Docs Hub nav link)
  - `app/services/pipeline/qdrant_client.rb:9-10` — `QDRANT_URL = ENV.fetch("QDRANT_URL", "http://192.168.100.186:6333")`, `OLLAMA_URL = ENV.fetch("OLLAMA_URL", "http://192.168.100.155:11434")`
  - `app/services/agent_auto_runner_service.rb:109` — `url = "http://192.168.100.186:18789" if url.blank?`
  - `config/database.yml:14` — default DB host `192.168.100.186`
  Impact: Moving the homeserver or switching to Render/Fly breaks all of these silently.
  Fix complexity: Small (2–8h) — replace defaults with ENV lookup that errors loudly on absence, or move to `Rails.application.config.x.openclaw_*`.

- **[HIGH] [EXPLOITABLE-LOW-EFFORT via DoS] [Medium] — Missing idempotency on `/hooks/clawtrol` event ingestion**
  Evidence: `app/controllers/api/v1/hooks_controller.rb#agent_complete` mutates task status and appends to transcripts without visible dedup key. If OpenClaw retries a webhook (network blip), the same agent_complete runs twice.
  Impact: Duplicate AgentActivityEvents, double-status moves, double-notifications.
  Fix: Require `X-Hook-Event-Id` header + dedup via `webhook_logs` model (already exists — `app/models/webhook_log.rb`).

- **[MEDIUM] [BAD-PRACTICE] — Broad `rescue => e` in dispatch_zeroclaw**
  Evidence: `app/controllers/api/v1/tasks_controller.rb#dispatch_zeroclaw` — `rescue => e; render json: { error: "Dispatch failed: #{e.message}" }, status: :unprocessable_entity`
  Impact: Swallows all errors including unrelated bugs. Should rescue specific exceptions.

- **[MEDIUM] [BAD-PRACTICE] — `transcript_watcher` is a `listen`-gem initializer**
  Evidence: Commit `ea3b0fd` says "guard transcript_watcher listen gem" — the initializer now guards against `listen` being missing in production. Historic breakage during earlier runs implied by the guard.

**What to fix first:** FIX PROMPT #5 (idempotency). Then centralize env lookups for IPs.

[SECTION COMPLETE: Domain 7]

---

### Domain 8: Legal / Privacy / Compliance — Rating 3/5

▶ **FOUNDER VIEW**
Single-operator, no payment processor, no mass user signups, no PII export feature yet. Low legal risk today. If you open signups tomorrow, you will need a privacy policy, consent banner, and a data-deletion pathway — none of which exist yet.
**FIX URGENCY:** Before any public signup launch.

▶ **TECHNICAL EVIDENCE**

- **[MEDIUM] — No privacy policy / ToS in routes** (`grep -n "privacy\|terms" config/routes.rb` returns empty beyond marketing pages).
- **[MEDIUM] — No GDPR export / delete endpoint.** User model has no `export_user_data` method; no `destroy_account` flow.
- **[MEDIUM] — AI model output stored without disclosure banner.** Agent transcripts stored; no explicit notice to the user that the transcript may contain AI-generated content and is retained.
- **[LOW] — OmniAuth GitHub stores `email_address` + avatar URL.** Consent implicit (user chose to OAuth); fine for internal use, thin for public launch.
- **[UNVERIFIED] — Font licenses** (Clash Display, Satoshi from fontshare) — free tier allows commercial use but confirm if this ships publicly.

[SECTION COMPLETE: Domain 8]

---

### Domain 9: DX & Maintainability — Rating 3/5

▶ **FOUNDER VIEW**
The project is surprisingly approachable for someone else to pick up. You have a CLAUDE.md, a rich handoff doc, CI running security scanners, and a mostly-Rails-idiomatic code layout. The weak spot is that 301 test files might or might not pass — that uncertainty is itself the issue.
**FIX URGENCY:** Before hiring your first engineer.

▶ **TECHNICAL EVIDENCE**

### §2.1 Maintainability Interview Test

1. **Where is the session token stored, and how is it invalidated on logout?**
   Stored in `Session` model (`app/models/session.rb`), referenced by signed cookie `:session_id` (`app/controllers/concerns/authentication.rb:66-75`), `httponly: true, same_site: :strict, secure: Rails.env.production?, expires: 30.days.from_now`. Logout: `terminate_session` at `authentication.rb:79-83` destroys the DB row and deletes the cookie. **Verdict: clean.**

2. **Trace a webhook from HTTP request to DB write.**
   Agent completion:
   - Request hits `POST /api/v1/hooks/agent_complete`
   - Route in `config/routes.rb` → `Api::V1::HooksController#agent_complete`
   - `before_action :authenticate_hook_token!` at `hooks_controller.rb:14` (secure_compare against `Rails.application.config.hooks_token`)
   - Finds task, calls `TranscriptArchiveService.call(task:, session_id:)` (synchronous, per P0 comment in code)
   - Updates task via `task.update!(updates)` + writes `AgentActivityEvent` records
   - No visible idempotency/dedup — this is the finding in Domain 7.

3. **IDOR safety — can User A see User B's data by changing an ID?**
   Tasks: **safe.** `current_user.tasks.find(params[:id])` pattern throughout `tasks_controller.rb`.
   Boards: **safe** (same pattern).
   Nightshift missions: **safe** (explicit `user_mission_ids` filtering).
   **FactoryAgent: not user-scoped** (global + per-creator builtin flag). Acceptable today (single-operator); becomes IDOR at multi-user.
   **LearningEffectiveness: not user-scoped** (untested from controller alone).
   **Pipeline: safe-ish** — uses `current_user.tasks` but with the "fallback to first admin" flaw.

4. **Deployment process from commit to prod?**
   CI runs 5 jobs on push/PR: brakeman + bundler-audit, importmap audit, rubocop, minitest (with Postgres 16), and system-test (Selenium). No CD. No CD — operator SSHs to VM, `git pull`, `bundle install`, `assets:precompile`, `systemctl --user restart clawtrol`. Not in version control. **Weak spot.**

5. **Env-specific config?**
   `config/environments/*.rb` + systemd unit ENV lines. Dev vs prod differ in `RAILS_SERVE_STATIC_FILES`, `RAILS_LOG_TO_STDOUT`, app base URL derivation, and SSL enforcement. No `.env.production` (it would be in env vars on the systemd unit).

- **[MEDIUM] — README likely stale** (not read in depth; last updated with clawdeck renaming?). Worth a pass.
- **[LOW] — Test suite health unknown, but CI does run it.** `.github/workflows/ci.yml` has a `test` job (`bin/rails db:test:prepare test`, Postgres 16 service) and a `system-test` job (with failure-screenshot upload). 301 test files present (controllers 141, services 89, models 41, jobs 19, system 2, integration 2 per `TESTING.md`). Pass rate unknown from repo alone — check the CI status page.
  Fix: Nothing urgent. If recent CI runs are red, fix the failures or mark as `skip` with documented reason.
- **[LOW] — No OpenAPI / Swagger documentation.** Given that OpenClaw is the primary external client of this API, a machine-readable spec would remove ambiguity.

[SECTION COMPLETE: Domain 9]

---

### Domain 10: Cost & Billing Risk — Rating 3/5

▶ **FOUNDER VIEW**
Your LLM spend can grow fast because there is no per-user cap and no circuit breaker. The cost tracking plumbing exists but is not wired to any alert or automatic shutoff. If the autonomous nightshift goes sideways, you will find out when the invoice arrives.
**FIX URGENCY:** Before leaving autonomous loops running unattended.

▶ **TECHNICAL EVIDENCE**

- **[HIGH] [BAD-PRACTICE] [High] — No hard per-user LLM spend cap**
  Evidence: `CostSnapshot` model tracks historical spend (`app/models/cost_snapshot.rb`) with `budget_limit` and `budget_exceeded` flag. No enforcement point: nothing in `app/controllers/api/v1/tasks_controller.rb` or `app/services/agent_auto_runner_service.rb` checks `CostSnapshot.over_budget?` before spawning agents.
  Impact: A runaway factory-loop or nightshift could rack up $100+/day without intervention.
  Fix: Add `before_action :enforce_budget_gate` on task spawn endpoints.

- **[MEDIUM] — `max_tokens` caps only on 2 service calls**
  Evidence: `app/services/ai_suggestion_service.rb:89` (500), `app/services/validation_suggestion_service.rb:177` (150). Every other LLM call goes through the OpenClaw gateway and depends on gateway-side caps.
  Impact: Cannot audit the upstream cap from this repo. Confirm with OpenClaw config.

- **[LOW] — No per-channel rate limit on agent spawn**
  Evidence: Rack::Attack has a task-creation throttle (`task_creation`, 10/min per user) but nothing on nightshift/factory_loop mission creation.

- **[LOW] — No billing alerts / notifications.**
  Evidence: `notifications_enabled` column exists on User; no code path notifies on budget breach.

[SECTION COMPLETE: Domain 10]

---

### Domain 11: Demo-to-Production Gap — Rating 2/5

▶ **FOUNDER VIEW**
The app is heavily coupled to your specific network: VM IP 192.168.100.186 is embedded in several code paths. Deploying this to the public cloud would require an afternoon of search-and-replace, not a `git push`.
**FIX URGENCY:** Before any cloud migration.

▶ **TECHNICAL EVIDENCE**

- **[HIGH]** — Hardcoded `192.168.100.186` references (5 files, detailed in Domain 7).
- **[HIGH]** — Postgres port mismatch (runtime 15432, repo 5432 everywhere). Tech mapper (`STACK.md`) confirmed it could not find `15432` in the repo.
- **[MEDIUM]** — Nginx config for `clawdeck.so` — aspirational, not live.
- **[MEDIUM]** — Dockerfile Ruby version drift (3.3.1 vs. 3.3.8).
- **[MEDIUM]** — `docker-compose.yml` maps Postgres on default port 5432 — contradicts runtime.
- **[LOW]** — Application module still `ClawDeck::Application` despite repo rename.

[SECTION COMPLETE: Domain 11]

---

### Domain 12: What's Missing But Expected — Rating 2/5

▶ **FOUNDER VIEW**
Everything that lets you sleep at night when running production software: error tracking, staging server, backups, API documentation, admin tooling. None of it is here. None of it is hard to add — but none of it is here.
**FIX URGENCY:** Staged — error tracking and backups are urgent; the rest is quarterly work.

▶ **TECHNICAL EVIDENCE**

**Observability:**
- ❌ Error tracking (Sentry/Honeybadger/GlitchTip)
- ❌ APM / performance monitoring
- ❌ Structured logging (plain Rails logger only)
- ❌ Uptime monitoring pointing at `/up` or `/health`
- ✅ `/up` and `/health` endpoints exist

**Security:**
- ✅ Brakeman, bundler-audit, importmap audit in CI
- ❌ Secret scanning (gitleaks, trufflehog) — would have caught the embedded gho_ token
- ❌ Dependency dashboard (Dependabot, Renovate)
- ❌ SBOM generation

**Deployment:**
- ❌ Staging environment
- ❌ Blue-green / canary deployment
- ❌ Automated rollback procedure
- ❌ Database migration safety checks (strong_migrations gem)

**Data safety:**
- ❌ Backup strategy documented in repo
- ❌ Point-in-time-recovery tested
- ❌ Data export for GDPR

**Dev workflow:**
- ❌ Pre-commit hooks (rubocop, brakeman on push)
- ❌ Conventional-commit enforcement
- ❌ PR template / issue template
- ❌ API documentation (OpenAPI/Swagger)

**Product operations:**
- ❌ Feature flags (flipper, flagsmith)
- ❌ Admin dashboard (Avo, RailsAdmin)
- ❌ Audit log for destructive actions
- ❌ Queue dashboard (SolidQueue has one at `/solid_queue` — unverified if mounted here)

[SECTION COMPLETE: Domain 12]

---

## 5. Risk Register (Medium and above)

| # | Risk | Sev | Lik | Domain | Evidence | Business Impact | Fix | Self-Serv | Fix Prompt |
|---|------|-----|-----|--------|----------|-----------------|-----|-----------|------------|
| 1 | Crash loop, prod unavailable | Crit | Certain | 4 | `config/puma.rb:45` vs unit file | Users cannot reach app | Trivial | Yes | FIX #1 |
| 2 | Plaintext secrets in systemd unit | Crit | High | 1,4 | `~/.config/systemd/user/clawtrol.service` | Session forge / full DB compromise | Small | Yes | FIX #2 |
| 3 | PipelineController admin-fallback | Crit | Medium | 1 | `pipeline_controller.rb:111` | IDOR at multi-tenant | Small | No | FIX #3 |
| 4 | HOOKS_TOKEN not set | High | Certain | 1 | Startup log | Webhook callbacks silently fail | Trivial | Yes | FIX #4 |
| 5 | Webhook idempotency missing | High | High | 7 | `hooks_controller.rb` | Duplicate task state on retries | Small | Yes | FIX #5 |
| 6 | DB superuser role | High | Low | 1,3 | Systemd unit | SQL injection blast radius | Small | Yes | FIX #6 |
| 7 | `tasks_controller.rb` god-file | High | Cert | 2 | 1000+ lines, 35+ actions | Contribution friction, slow tests | Medium | Yes | — |
| 8 | Inconsistent `PipelineController` inheritance | High | Cert | 2 | Diverges from `BaseController` | Maintenance drift | Small | Yes | — |
| 9 | No per-user LLM budget gate | High | Medium | 10 | `CostSnapshot` unused at spawn sites | Billing runaway | Small | Yes | FIX #7 |
| 10 | Hardcoded VM IPs | High | Cert | 7,11 | 5 files | Portability broken | Small | Yes | — |
| 11 | No error tracking | High | Cert | 4,12 | Gemfile | Silent failures | Trivial | Yes | — |
| 12 | No staging env | High | Cert | 4,12 | `config/environments/` | Direct-to-prod changes | Small | Yes | — |
| 13 | Test suite runs in CI — pass rate unverified | Low | Unk | 9 | `.github/workflows/ci.yml` test+system-test jobs | Regressions possibly unnoticed if red & ignored | Trivial verification | Yes | — |
| 14 | `X-INTERNAL-REQUEST` header bypass | Med | Low | 1 | `rack_attack.rb:13` | Rate-limit evasion | Trivial | Yes | — |
| 15 | 167 un-squashed migrations | Med | Cert | 3 | `db/migrate/` | Slow environment setup | Small | Yes | — |
| 16 | Interpolated SQL in HAVING | Med | Low | 3 | `transcript_retroactive_archive_job.rb:50` | Pattern normalization | Trivial | Yes | — |
| 17 | Missing idempotency on webhooks | Med | High | 7 | `hooks_controller.rb` | Duplicate events | Small | Yes | FIX #5 |
| 18 | Unused `faraday`/`httparty` gems | Med | Cert | 2 | `Gemfile:44-46` | Attack surface / bloat | Trivial | Yes | — |
| 19 | App module named `ClawDeck::Application` | Med | Cert | 2,11 | `config/application.rb` | Confusion | Small | Yes | — |
| 20 | `credentials.yml.enc` orphaned (no master.key) | Med | Cert | 1 | `config/master.key` missing | Dead config | Trivial | Yes | — |

Medium count: 8. Score contribution: 8 × 2 = 16 → but top-line score of 42 above is based on Crit+High only. Including Medium, full score = 42 + 16 = 58, which would downgrade verdict to "DO NOT LAUNCH WITHOUT CONDITIONS". The Medium findings are the main reason the project sits on the border.

---

## 6. AI Fix Prompts

See `FIX_PROMPTS.md` for the full self-contained prompts (1 per Critical/High finding).

---

## 7. Triage Summary

**Fix this week (trivial, <2h each):**
- FIX #1 — Crash loop (systemd + puma pidfile)
- FIX #4 — Set HOOKS_TOKEN env var
- Commit uncommitted layout fixes
- Remove `X-INTERNAL-REQUEST` header safelist line from `rack_attack.rb`
- Remove unused `faraday`, `httparty` from Gemfile, `bundle install`
- Delete orphaned `config/credentials.yml.enc` (or restore with master.key)

**Fix before launch (small–medium, high ROI):**
- FIX #2 — Move secrets to `EnvironmentFile=`
- FIX #3 — PipelineController fallback logic
- FIX #5 — Webhook idempotency via `X-Hook-Event-Id` + `webhook_logs`
- FIX #6 — Downgrade DB role
- FIX #7 — Budget gate on task spawn
- Fix Dockerfile Ruby version to 3.3.8
- Centralize hardcoded IPs into `Rails.application.config.x.openclaw`
- Verify CI test + system-test jobs are green; fix red tests if present
- Integrate Sentry (or GlitchTip) free tier

**Requires engineer hire (do not attempt with AI alone):**
- Split `tasks_controller.rb` safely (breakage risk without tests)
- Migrate SolidQueue out of Puma once traffic warrants (operational care)
- Design multi-tenant story if public launch is on roadmap

**Accept and monitor (known risk, not economic to fix now):**
- 167 migrations (squash during next major cut)
- Nginx config for unused domain (remove on next deployment refresh)
- README clawdeck → clawtrol rename

**Total estimated remediation:** 2–4 developer-weeks to production-grade.

---

## 8. Missing But Expected

(See Domain 12 checklist.) Priority order to add:
1. Error tracking (Sentry) — this week.
2. Backup script + restore drill — this week.
3. Staging environment — within the month.
4. OpenAPI spec for `/api/v1/*` — within the month (auto-generate via `rswag`).
5. Admin dashboard (Avo) — quarter.
6. Feature flags (Flipper) — when 2nd user exists.

---

## 9. Repair vs. Rewrite

**Can this codebase be safely evolved?** Yes.
**Which parts are salvageable? Which cheaper to rewrite?**
- **Salvageable (90% of the repo):** Models, views, auth layer, Rack::Attack, jobs, services, channels.
- **Refactor in place:** `tasks_controller.rb` (split), `pipeline_controller.rb` (inherit `BaseController`), systemd unit, Dockerfile.
- **Rewrite candidates:** None. The architecture is sound Rails, not spaghetti.

**If acquired, would you freeze feature development first?** Yes, for ~1 week to land P0/P1 (crash fix, secret rotation, idempotency, budget gate). After that, unfreeze.

**Decay check (git history on critical paths):**
- `app/controllers/concerns/authentication.rb` — last modified in the fork era; stable.
- `app/models/task.rb` — hot file, active churn (~20 commits/month). Healthy.
- `app/controllers/api/v1/tasks_controller.rb` — hot and growing. Splitting overdue.
- `config/environments/production.rb` — recent touch (SSL disable commit `ea3b0fd`). Healthy.

No decay candidates identified — this project is under active development; the issue is velocity, not neglect.

---

## 10. First 30 Days Stabilization Plan

**Days 1–3 (hard-stop → critical fixes):**
- D1: FIX #1 (crash loop). FIX #4 (HOOKS_TOKEN). Commit layout fixes. Rotate gho_ OAuth token (user action).
- D2: FIX #2 (secrets to EnvironmentFile). FIX #6 (DB role).
- D3: FIX #3 (PipelineController auth). FIX #5 (webhook idempotency).

**Week 1 (containment for Criticals):**
- Sentry integration. Budget gate (FIX #7). Test suite runs in CI. Remove unused gems.

**Weeks 2–3 (structural fixes for High severity):**
- Split `tasks_controller.rb` (feature-branched, rolled out per action).
- `PipelineController` inherits `BaseController`.
- Centralize hardcoded IPs.
- Add staging environment.
- Add `rails test` to CI.

**Week 4 (operational hardening):**
- Backup script + quarterly restore drill.
- Uptime monitoring (UptimeRobot or self-hosted Uptime Kuma).
- OpenAPI spec.
- `strong_migrations` gem.

**Distinctions:**
- (a) **Product-decision items:** multi-tenant roadmap (blocks Pipeline auth redesign).
- (b) **Engineering-can-do-immediately:** FIX #1, #4, #5, #7, CI test step.
- (c) **Blocked on infra/platform access:** none — you own the VM.
- (d) **Needs original developer knowledge:** tasks_controller split rationale; which OpenClaw flows are live.

---

## 11. Top 10 Actions, in Order

| # | Action | If ignored | Fix | Risk reduction | Self-serv |
|---|--------|------------|-----|----------------|-----------|
| 1 | Fix puma/systemd PIDFile (FIX #1) | App stays offline | Trivial | High | Yes |
| 2 | Move secrets out of systemd unit (FIX #2) | VM compromise = session forge | Small | High | Yes |
| 3 | Set HOOKS_TOKEN (FIX #4) | OpenClaw callbacks silently fail | Trivial | High | Yes |
| 4 | Patch PipelineController fallback (FIX #3) | IDOR at multi-tenant | Small | High | No (needs design call) |
| 5 | Rotate leaked gho_ token | Already burnt; still revoke | Trivial | High | Yes (manual via github.com) |
| 6 | Commit uncommitted layout fixes | Regression on next reset | Trivial | Medium | Yes |
| 7 | Webhook idempotency (FIX #5) | Duplicate events under retry | Small | Medium | Yes |
| 8 | Add Sentry + `rails test` to CI | Silent regressions | Small | Medium | Yes |
| 9 | Per-user LLM budget gate (FIX #7) | Billing runaway | Small | Medium | Yes |
| 10 | Downgrade DB role (FIX #6) | Blast radius on future SQLi | Small | Medium | Yes |

---

## 12. Founder FAQ

1. **Can this handle 100 simultaneous users today?** No. Puma is 1-worker / 3-thread default; SolidQueue shares the process; no cache on analytics. 10 users: fine. 100: queue dashboards lag.
2. **If the main developer disappeared, could someone else maintain this?** Yes, within a week of ramp-up. CLAUDE.md + the handoff document + standard Rails 8 idioms make this tractable. Primary onboarding friction: the 1000+-line `tasks_controller.rb` and the multi-layer pipeline refactor-in-flight.
3. **Is there anything here that could get me sued, fined, or investigated?** Unlikely today. No payments, no PII scale, single-operator. At public launch: need privacy policy, data deletion, GDPR export.
4. **Single most important thing to fix before launch?** The crash loop (FIX #1). Nothing else matters until the app stays up.
5. **How much to bring this to production-grade?** 2–4 developer-weeks, single senior engineer.
6. **Most likely thing to go wrong in the first 30 days after launch?** LLM bill runaway via autonomous nightshift / factory-loop without a budget gate. Second most likely: webhook duplicate events from OpenClaw retry storm.

---

## 13. Appendix — Evidence Index

**Auth layer**
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/authentication.rb` (L1-83)
- `app/controllers/api/v1/base_controller.rb` (L5-11 auth wiring; L16-20 rescues)
- `app/controllers/concerns/api/token_authentication.rb` (L16-24 auth flow; L36-41 session fallback)
- `app/controllers/concerns/api/hook_authentication.rb` (L13-20 timing-safe compare)
- `app/models/session.rb` (full)
- `app/models/api_token.rb` (referenced via `ApiToken.authenticate`)

**Pipeline / PipelineController issue**
- `app/controllers/api/v1/pipeline_controller.rb` (L5 inheritance, L6 auth, L96-122 local auth)
- `app/controllers/pipeline_dashboard_controller.rb:27` (parameterized ILIKE)
- `app/services/pipeline/*.rb`

**Webhook lane**
- `app/controllers/api/v1/hooks_controller.rb` (L1-80 agent_complete)
- `app/controllers/api/v1/nightshift_controller.rb:9-10` (skip+hook-auth)
- `app/models/webhook_log.rb` (idempotency candidate table — exists, unused)

**Infra / deployment**
- `~/.config/systemd/user/clawtrol.service` (full)
- `config/puma.rb:43,45`
- `Dockerfile:5`
- `docker-compose.yml`
- `config/nginx/*.conf`
- `.github/workflows/ci.yml`

**Rate limiting**
- `config/initializers/rack_attack.rb` (L13-17 safelist, L26-58 throttles)

**Secrets / config**
- `config/credentials.yml.enc` (orphaned — no master.key)
- `config/initializers/hooks_token_validation.rb`
- `config/initializers/filter_parameter_logging.rb`
- `config/initializers/content_security_policy.rb`

**Task model core**
- `app/models/task.rb:14-39` (associations), `:88-95` (validations), `:123` (Arel.sql scope)

**Demo-to-prod gaps**
- `app/helpers/navigation_helper.rb:72`
- `app/services/pipeline/qdrant_client.rb:9-10`
- `app/services/agent_auto_runner_service.rb:109`
- `config/database.yml:14`

**Cost / budget**
- `app/models/cost_snapshot.rb:18,30,37-40,114-115`
- `app/services/ai_suggestion_service.rb:89`
- `app/services/validation_suggestion_service.rb:177`

**Markdown / HTML sanitization**
- `app/helpers/markdown_sanitization_helper.rb:40-48`
- `app/views/boards/tasks/diff_file.html.erb:60`
- `app/views/marketing/index.html.erb:78,109`

**Rendered ERB with raw HTML**
- `app/views/nightshift/index.html.erb:134` (static emoji)

---

## End of Audit

Vibe Debt Score: **42 / 100** · Verdict: **FIX BEFORE LAUNCH** · Est. remediation: 2–4 dev-weeks · Top risk: currently-crashing production · Rotate the gho_ GitHub token today.
