# ClawTrol — AI Fix Prompts

**Target repo:** `/home/ggorbalan/clawdeck/` on VM 192.168.100.186
**Branch:** `audit/2026-04-17`
**Audience:** non-technical founder pasting into Claude Code / Cursor / Codex.
**Rule:** every prompt is self-contained — paste verbatim. Each ends with a verification command you can run yourself.

---

## FIX #1 — Crash loop (systemd PIDFile vs Puma `-d` mismatch)

**Severity:** Critical
**Linked finding:** Domain 4, bullet 1
**Self-serviceable:** Yes

### CONTEXT (paste verbatim)

The ClawTrol Rails service on Ubuntu crash-loops every ~20 seconds. Root cause: the systemd unit at `~/.config/systemd/user/clawtrol.service` declares `Type=forking` with `PIDFile=/home/ggorbalan/clawdeck/tmp/pids/server.pid`, and starts Puma with `-d` (daemonize). But `config/puma.rb:45` only writes a pidfile if `ENV["PIDFILE"]` is set — and the systemd unit does not set that env var. So systemd cannot track the forked Puma, `ExecStop=/bin/kill -QUIT $MAINPID` becomes `kill ""` (fails), and the service is marked failed → restart. Journalctl shows `Can't open PID file ... (yet?)` and `Referenced but unset environment variable evaluates to an empty string: MAINPID`.

### GOAL

The ClawTrol service stays running on port 4001 without restart loops. `curl http://127.0.0.1:4001/up` returns HTTP 200 for at least 5 minutes.

### CHANGES REQUIRED

1. Edit `~/.config/systemd/user/clawtrol.service`:
   - Change `Type=forking` to `Type=simple`.
   - Remove `PIDFile=/home/ggorbalan/clawdeck/tmp/pids/server.pid`.
   - Change `ExecStart` to drop the `-d` flag: `ExecStart=/home/ggorbalan/.rbenv/versions/3.3.8/bin/bundle exec rails server -b 0.0.0.0 -p 4001 -e production`.
   - Change `ExecStop=/bin/kill -QUIT $MAINPID` to `ExecStop=/bin/kill -QUIT $MAINPID` — with `Type=simple`, `MAINPID` is populated automatically, so this now works. (Or delete the line entirely and let systemd default to SIGTERM.)
   - Keep all other lines the same.
2. Run: `systemctl --user daemon-reload`
3. Run: `systemctl --user restart clawtrol`
4. Watch: `journalctl --user -u clawtrol -f` for 30 seconds — should show `Listening on http://0.0.0.0:4001` and nothing else.

### DO NOT

- Do not set `ENV["PIDFILE"]` as a workaround — that fights the better Type=simple approach.
- Do not run `puma` directly; keep using `bundle exec rails server`.
- Do not add `daemonize true` to `config/puma.rb`.

### VERIFICATION

```bash
# Wait 10 seconds after restart
sleep 10

# Should print 200 three times in a row
for i in 1 2 3; do curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4001/up; sleep 2; done

# Restart counter must be low
systemctl --user show clawtrol --property=NRestarts
# Expect NRestarts=0 or 1 (the one we just triggered), not 27.
```

### ROLLBACK

`cp ~/.config/systemd/user/clawtrol.service.bak ~/.config/systemd/user/clawtrol.service && systemctl --user daemon-reload && systemctl --user restart clawtrol` — make the `.bak` copy BEFORE editing.

---

## FIX #2 — Move secrets out of systemd unit into a 0600 EnvironmentFile

**Severity:** Critical
**Linked finding:** Domain 1, bullet 1 (and Domain 4 cross-link)
**Self-serviceable:** Yes

### CONTEXT

`~/.config/systemd/user/clawtrol.service` currently has `SECRET_KEY_BASE` (128 hex chars) and `DATABASE_URL` (with `postgres:postgres` creds) hardcoded in `Environment=` lines. Any process running as `ggorbalan` can read `/proc/<puma-pid>/environ` and exfiltrate the secret. `SECRET_KEY_BASE` lets an attacker forge signed cookies and session tokens.

### GOAL

All sensitive env vars move to `/etc/clawtrol/clawtrol.env` (root:root, 0600), referenced from the systemd unit via `EnvironmentFile=`. The secrets are no longer visible in `systemctl --user show clawtrol` or `/proc/<pid>/environ` to other users (0600 perms on the file block read access from the rest of the system).

### CHANGES REQUIRED

1. As root: create `/etc/clawtrol/` owned by `root:ggorbalan`, mode `0750`.
2. As root: create `/etc/clawtrol/clawtrol.env` with:
   ```
   SECRET_KEY_BASE=<existing value — copy from current systemd unit>
   DATABASE_URL=<existing value>
   HOOKS_TOKEN=<generate new: `openssl rand -hex 32`>
   CLAWTROL_API_TOKEN=<generate new: `openssl rand -hex 32`>
   APP_BASE_URL=http://192.168.100.186:4001
   RAILS_ENV=production
   RAILS_SERVE_STATIC_FILES=true
   RAILS_LOG_TO_STDOUT=true
   ```
   Owner: `root:ggorbalan`. Mode: `0640` (owner read/write, group read — so Rails user can read, but other users cannot).
3. Edit `~/.config/systemd/user/clawtrol.service`:
   - Remove the `Environment=SECRET_KEY_BASE=...`, `Environment=DATABASE_URL=...`, `Environment=RAILS_ENV=...`, `Environment=RAILS_SERVE_STATIC_FILES=...`, `Environment=RAILS_LOG_TO_STDOUT=...`, `Environment=APP_BASE_URL=...` lines.
   - Keep only: `Environment=PATH=...`.
   - Add: `EnvironmentFile=/etc/clawtrol/clawtrol.env`.
4. Rotate `SECRET_KEY_BASE` after copying the old value (generate a new one with `bundle exec rails secret`). Note: this invalidates all active user sessions — acceptable for a single-operator app.
5. `systemctl --user daemon-reload && systemctl --user restart clawtrol`.

### DO NOT

- Do not `chmod 0777` the env file.
- Do not commit `/etc/clawtrol/clawtrol.env` or any copy of it to git.
- Do not put the env file inside `~/clawdeck/` — it must live outside the repo.

### VERIFICATION

```bash
# Perms check
ls -la /etc/clawtrol/clawtrol.env
# Expect: -rw-r----- 1 root ggorbalan ... clawtrol.env

# Rails still boots
curl -sS http://127.0.0.1:4001/up
# Expect: 200

# Secrets NOT visible in `systemctl show`
systemctl --user show clawtrol --property=Environment | grep -i secret
# Expect: no output (SECRET_KEY_BASE no longer in the unit-level environment listing)

# Secrets NOT readable by another user
sudo -u nobody cat /etc/clawtrol/clawtrol.env
# Expect: Permission denied
```

### ROLLBACK

Keep a backup of the old unit file. `git stash` any puma.rb changes. Rollback = restore backup + daemon-reload + restart.

---

## FIX #3 — Remove "fallback to first admin user" in PipelineController

**Severity:** Critical
**Linked finding:** Domain 1, bullet 2
**Self-serviceable:** No (needs product decision on intended behavior)

### CONTEXT

`app/controllers/api/v1/pipeline_controller.rb:96-112` defines a local `authenticate_user!` method that, when a request comes in with a valid `HOOKS_TOKEN` but no specific user identifier, sets `@current_user = User.where(admin: true).first || User.first`. This is a latent IDOR: anyone with the shared hooks token sees/mutates the first admin user's data. Single-operator today; real exposure the moment a second user exists.

### GOAL

`PipelineController` requires an explicit user association for every request. There is no implicit fallback. Behavior is one of: (a) inherit `BaseController` and use standard bearer-token auth; (b) accept `X-User-Id` header on hook-authenticated requests and 401 if missing.

### DECISION REQUIRED BEFORE CODE CHANGE

- Is `/api/v1/pipeline/*` called by OpenClaw via hook token, or by the user directly via browser/bearer token?
- If hook token: what identifies the user the hook pertains to?

### CHANGES REQUIRED

Option A (recommended if pipeline is user-facing):
1. `class PipelineController < BaseController` (inherit, use standard auth).
2. Remove the local `authenticate_user!` and `current_user` overrides (lines 96-122).
3. Any test or route configuration pointing to hook-auth for pipeline: switch to standard bearer token.

Option B (if pipeline must support hook-auth):
1. Replace the fallback at line 111 with: `render json: { error: "X-User-Id header required for hook-authenticated pipeline requests" }, status: :bad_request; return`.
2. Add `user_id = request.headers["X-User-Id"]&.to_i; @current_user = User.find_by(id: user_id); return render(json: {error: "user not found"}, status: 401) unless @current_user`.
3. Update OpenClaw gateway config to include `X-User-Id` header on pipeline hook calls.

### DO NOT

- Do not silently default to the first user found.
- Do not rely on `Rails.logger.warn` as the mitigation (current state — useless).

### VERIFICATION

```bash
# Should now 401 without a valid user
curl -sS -H "X-Hook-Token: $HOOKS_TOKEN" http://127.0.0.1:4001/api/v1/pipeline/status
# Expect: 400 or 401, NOT 200 with a list of another user's tasks.
```

---

## FIX #4 — Set HOOKS_TOKEN in production

**Severity:** High
**Linked finding:** Domain 1, bullet 3
**Self-serviceable:** Yes

### CONTEXT

Every production boot logs `[SECURITY] HOOKS_TOKEN environment variable is not set in production!`. All webhook endpoints (`/api/v1/hooks/*`, nightshift sync routes) reject every request because `authenticate_hook_token!` requires a non-empty configured token. OpenClaw → ClawTrol callbacks silently fail.

### GOAL

`HOOKS_TOKEN` is set in the production environment. Webhook endpoints accept valid tokens and reject invalid ones. The OpenClaw gateway is configured with the same token.

### CHANGES REQUIRED

1. Generate: `openssl rand -hex 32` → save the value.
2. Add to `/etc/clawtrol/clawtrol.env` (see FIX #2): `HOOKS_TOKEN=<the generated value>`.
3. Update OpenClaw gateway config (on OpenClaw side, not in this repo) to send `X-Hook-Token: <same value>` on all callbacks.
4. `systemctl --user restart clawtrol`.

### VERIFICATION

```bash
# Should 200 with correct token
curl -sS -X POST -H "X-Hook-Token: <the token>" -H "Content-Type: application/json" \
  -d '{}' http://127.0.0.1:4001/api/v1/hooks/health 2>&1 | head -5
# Expect: 200 or 404 (depending on if that endpoint exists), NOT 401

# Should 401 with wrong token
curl -sS -X POST -H "X-Hook-Token: wrong" http://127.0.0.1:4001/api/v1/hooks/agent_complete
# Expect: {"error":"unauthorized"} with status 401

# Startup log no longer contains the warning
journalctl --user -u clawtrol --since "1 min ago" | grep -i "HOOKS_TOKEN"
# Expect: no output (or only "set successfully" info, not "not set")
```

---

## FIX #5 — Webhook idempotency via `X-Hook-Event-Id` + `webhook_logs`

**Severity:** High
**Linked finding:** Domain 7, bullet 2
**Self-serviceable:** Yes (but test thoroughly — touches hot path)

### CONTEXT

`app/controllers/api/v1/hooks_controller.rb` processes `agent_complete` callbacks by mutating task status, persisting transcripts, and writing `AgentActivityEvent` records. There is no dedup key. If OpenClaw retries a callback (network blip, 504 timeout), the same logic runs twice — duplicate events, double status moves, double notifications. The repo already has a `WebhookLog` model (`app/models/webhook_log.rb`) that is seemingly unused for this purpose.

### GOAL

Every inbound hook carries a unique `X-Hook-Event-Id`. If that ID has been seen before for the same task, the second call returns the cached previous response with HTTP 200 — no state mutation.

### CHANGES REQUIRED

1. Inspect `app/models/webhook_log.rb` for existing columns. If it already has `event_id`, `endpoint`, `response_body` — use those. If not, add a migration:
   ```ruby
   class AddEventIdToWebhookLogs < ActiveRecord::Migration[8.1]
     def change
       add_column :webhook_logs, :event_id, :string
       add_column :webhook_logs, :endpoint, :string
       add_column :webhook_logs, :response_body, :jsonb, default: {}
       add_column :webhook_logs, :response_status, :integer
       add_index :webhook_logs, [:endpoint, :event_id], unique: true
     end
   end
   ```
2. Extract a concern `Api::WebhookIdempotency` with:
   ```ruby
   module Api
     module WebhookIdempotency
       extend ActiveSupport::Concern

       def idempotent_hook!
         event_id = request.headers["X-Hook-Event-Id"].to_s
         return yield if event_id.blank? # tolerant — log and proceed for backfills

         endpoint = "#{controller_name}##{action_name}"
         existing = WebhookLog.find_by(endpoint: endpoint, event_id: event_id)
         if existing
           render json: existing.response_body.presence || { ok: true, replay: true },
                  status: existing.response_status || 200
           return
         end

         result = yield
         WebhookLog.create!(
           endpoint: endpoint, event_id: event_id,
           response_body: result.is_a?(Hash) ? result : {},
           response_status: response.status
         )
       end
     end
   end
   ```
3. In `hooks_controller.rb` + nightshift hook actions: wrap each hook action body in `idempotent_hook! { ... }`.
4. Update OpenClaw gateway to send `X-Hook-Event-Id: <UUID>` per event.

### DO NOT

- Do not silently skip the entire action when event_id is missing — keep the "tolerant" branch for legacy callers, but log a warning.
- Do not use the HTTP response body from Rails serialization as the cache — cache the intended response payload before rendering.

### VERIFICATION

```bash
# First call writes task state
curl -sS -X POST -H "X-Hook-Token: $HOOKS_TOKEN" -H "X-Hook-Event-Id: test-123" \
  -H "Content-Type: application/json" -d '{"task_id":1,"findings":"ok"}' \
  http://127.0.0.1:4001/api/v1/hooks/agent_complete

# Second call with same Event-Id must NOT mutate state
curl -sS -X POST -H "X-Hook-Token: $HOOKS_TOKEN" -H "X-Hook-Event-Id: test-123" \
  -H "Content-Type: application/json" -d '{"task_id":1,"findings":"ok"}' \
  http://127.0.0.1:4001/api/v1/hooks/agent_complete
# Expect: same body as first call, but no new AgentActivityEvent row.

bundle exec rails runner "puts Task.find(1).agent_activity_events.count"
# Should equal the count after the first call, not double.
```

---

## FIX #6 — Downgrade Postgres role from superuser

**Severity:** High
**Linked finding:** Domain 1, bullet 4 (and Domain 3)
**Self-serviceable:** Yes

### CONTEXT

`DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:15432/clawdeck_production` uses the Postgres superuser role. Any Rails SQL injection or ORM escape would have DB-superuser blast radius (DROP, CREATE EXTENSION, COPY FROM PROGRAM bypass of `fs_superuser`). The application only needs DML (SELECT/INSERT/UPDATE/DELETE) and migrations (DDL).

### GOAL

A dedicated `clawtrol_app` role owns the schema, has connect + schema-usage + DML, and can run migrations. The `postgres` superuser is used only for setup and emergency operations.

### CHANGES REQUIRED

1. Create the role in the Docker Postgres:
   ```sql
   CREATE USER clawtrol_app WITH PASSWORD '<generated-32-char>';
   GRANT CONNECT ON DATABASE clawdeck_production TO clawtrol_app;
   \c clawdeck_production
   GRANT USAGE ON SCHEMA public TO clawtrol_app;
   GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO clawtrol_app;
   GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO clawtrol_app;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO clawtrol_app;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO clawtrol_app;
   ```
2. Update `/etc/clawtrol/clawtrol.env`: `DATABASE_URL=postgresql://clawtrol_app:<pwd>@127.0.0.1:15432/clawdeck_production`.
3. `systemctl --user restart clawtrol`.
4. Keep a separate `DATABASE_ADMIN_URL` (superuser) only for running migrations: `DATABASE_URL=$DATABASE_ADMIN_URL bundle exec rails db:migrate`. Document this in `README.md`.

### DO NOT

- Do not DROP the `postgres` superuser (you still need it).
- Do not grant `CREATEDB` or `SUPERUSER` to `clawtrol_app`.

### VERIFICATION

```bash
# App still works
curl -sS http://127.0.0.1:4001/up
# Expect: 200

# New role cannot create extensions
docker exec -it <postgres-container> psql -U clawtrol_app -d clawdeck_production \
  -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
# Expect: ERROR: permission denied to create extension

# Migrations still run with superuser URL
DATABASE_URL=$DATABASE_ADMIN_URL bundle exec rails db:migrate:status
# Expect: list of migration status.
```

---

## FIX #7 — Per-user LLM budget gate on task spawn

**Severity:** High
**Linked finding:** Domain 10, bullet 1
**Self-serviceable:** Yes

### CONTEXT

`CostSnapshot` already tracks spend with `budget_limit` and `budget_exceeded` (`app/models/cost_snapshot.rb:114-115`), but nothing stops agent spawn when the budget is breached. An autonomous nightshift or factory-loop can run up $100/day unnoticed. `User.notifications_enabled` exists but no code path notifies on budget breach.

### GOAL

Before spawning any agent task, the system checks `current_user`'s current cost snapshot against their configured cap. If over budget, spawn is rejected with HTTP 402 (Payment Required) and an explanatory error body.

### CHANGES REQUIRED

1. Add migration:
   ```ruby
   class AddBudgetCapToUsers < ActiveRecord::Migration[8.1]
     def change
       add_column :users, :daily_budget_usd, :decimal, precision: 10, scale: 2
       add_column :users, :monthly_budget_usd, :decimal, precision: 10, scale: 2
     end
   end
   ```
2. Add method to `User`:
   ```ruby
   def over_budget?
     today = CostSnapshot.for_user(self).for_period(:day, Date.current).first
     month = CostSnapshot.for_user(self).for_period(:month, Date.current.beginning_of_month).first
     (daily_budget_usd.present? && today&.total_cost.to_f >= daily_budget_usd) ||
     (monthly_budget_usd.present? && month&.total_cost.to_f >= monthly_budget_usd)
   end
   ```
3. Add `before_action :enforce_budget_gate, only: [:create, :spawn_via_gateway, :dispatch_zeroclaw, :run_lobster]` in `TasksController`:
   ```ruby
   def enforce_budget_gate
     return unless current_user.over_budget?
     render json: { error: "Budget cap reached. Raise cap or wait for next period." },
            status: :payment_required
   end
   ```
4. Same gate in `FactoryLoopsController#run`, `NightshiftController#create_mission` (pre-flight).
5. Expose daily/monthly cap in user settings UI.
6. When budget is hit, enqueue a notification to `User.notifications` channel and, if `notifications_enabled`, a Telegram DM via the existing Telegram integration.

### DO NOT

- Do not reject read-only endpoints (`/api/v1/tasks` GET, analytics) — only agent-spawning ones.
- Do not silently downgrade to cheaper models; fail loudly so the operator notices.

### VERIFICATION

```bash
# Set a cap of $0.01
bundle exec rails runner "User.first.update!(daily_budget_usd: 0.01)"

# Force cost snapshot to be over
bundle exec rails runner "CostSnapshot.create!(user: User.first, period_type: 'day', period_start: Date.current, total_cost: 1.00, budget_limit: 0.01)"

# Spawn attempt must 402
curl -sS -X POST -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
  -H "Content-Type: application/json" -d '{"task":{"name":"test"}}' \
  http://127.0.0.1:4001/api/v1/tasks
# Expect: HTTP 402 with error about budget.
```

---

## Also worth patching (not full prompts — smaller changes)

- **Remove `X-INTERNAL-REQUEST` header safelist** in `config/initializers/rack_attack.rb:13` — delete the `req.env["HTTP_X_INTERNAL_REQUEST"] == "true" ||` line. LAN IP safelist remains.
- **Remove unused gems** — from `Gemfile`, delete `gem "faraday", ...` and `gem "httparty"`. Run `bundle install`.
- **Fix Dockerfile Ruby version** — change `ARG RUBY_VERSION=3.3.1` to `ARG RUBY_VERSION=3.3.8` in `Dockerfile:5`.
- **Centralize hardcoded IPs** — replace the 5 `192.168.100.186` occurrences in `app/services/pipeline/qdrant_client.rb:9-10`, `app/services/agent_auto_runner_service.rb:109`, `app/helpers/navigation_helper.rb:72`, `app/jobs/nightshift_runner_job.rb` with `Rails.application.config.x.openclaw.<url>` pulled from env with no host-specific fallback (raise if env missing).
- **Commit uncommitted layout fixes** on `audit/2026-04-17` so the Tailwind link survives future resets.
- **Rename app module** — `config/application.rb` — `module ClawDeck` → `module Clawtrol`. Rails will need a global rename.
- **Delete or restore `config/credentials.yml.enc`** — since `config/master.key` is missing, the file is dead weight. Either `rm` it or generate a new master key and re-encrypt.
- **Clean up systemd ExecStop** — after FIX #1, the line can be removed entirely.
- **Add Sentry** — `gem "sentry-ruby", "~> 5.17"` + `gem "sentry-rails", "~> 5.17"` and a `config/initializers/sentry.rb` wired to `SENTRY_DSN` env var. GlitchTip self-hosted is a free alternative.

---

## Feature proposals (requested by owner)

**Priority-ranked**, each with rough sizing. Not Critical/High — purely additive. See `FEATURE_IDEAS.md` for detail.

| Feature | Rough size | Why |
|---------|-----------|-----|
| OpenAPI spec for /api/v1/* | 2–3 days | Machine-readable contract for OpenClaw |
| Multi-model debate UI | 1 week | Already in handoff roadmap, differentiator |
| Cost alerts via Telegram + daily digest | 2 days | Pairs with FIX #7 |
| GitHub integration: auto-create tasks from issues | 3 days | Repo already uses GitHub |
| Better transcript viewer (search, syntax highlight) | 3 days | Quality-of-life |
| Admin dashboard (Avo mount) | 1 day | Replace ad-hoc rails console |
| Feature flags (Flipper mount) | 1 day | Enables staged rollouts |
| Strong migrations gem | 1 hour | Prevent painful migrations |
| `rswag` for auto OpenAPI | 1 day | Generates #1 from tests |
| Backup script with daily cron + restore runbook | 1 day | No evidence of any backup today |

---

**End of fix prompts.**
