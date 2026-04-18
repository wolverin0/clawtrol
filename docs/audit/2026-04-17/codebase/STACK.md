# ClawTrol — Technology Stack

_Dated: 2026-04-17_

ClawTrol is a Rails 8.1 kanban dashboard for orchestrating AI coding agents. It is a fork of ClawDeck and talks to the OpenClaw gateway runtime for session spawn, model inventory, and transcript streaming. Application module is still `ClawDeck::Application` (`config/application.rb`).

## Core Runtime

| Concern | Choice | Version / Notes | Source |
|---|---|---|---|
| Language | Ruby | 3.3.1 | `.ruby-version` |
| Framework | Rails | 8.1.0 (`config.load_defaults 8.1`) | `Gemfile`, `config/application.rb` |
| App server | Puma | 7.2.0 | `Gemfile.lock`, `config/puma.rb` |
| Boot cache | bootsnap | required in boot | `Gemfile` |
| Env vars (dev/test) | dotenv-rails | 3.1.8, dev+test groups only | `Gemfile` |

## Web Layer

| Concern | Choice | Notes | Source |
|---|---|---|---|
| Asset pipeline | Propshaft | 1.3.1 | `Gemfile.lock` |
| JS bundling | importmap-rails | 2.2.3, ESM import maps | `Gemfile`, `config/importmap.rb` |
| SPA accelerator | turbo-rails | 2.0.17 | `Gemfile.lock` |
| JS framework | stimulus-rails | 1.3.4 (controllers in `app/javascript/controllers/`) | `Gemfile.lock` |
| CSS | tailwindcss-rails | 4.4.0 | `Gemfile.lock` |
| JSON views | jbuilder | 2.14.1 | `Gemfile.lock` |
| Markdown render | redcarpet | 3.6.1 | `Gemfile` |
| Diff rendering | diffy | 3.4.4 | `Gemfile` |
| Pagination | pagy | 43.2.9, initializer at `config/initializers/pagy.rb` | `Gemfile` |
| Charts | chartkick 5.2 + groupdate 6.7 | Dashboard analytics | `Gemfile` |

## Data & Persistence

| Concern | Choice | Notes | Source |
|---|---|---|---|
| Primary DB | PostgreSQL via `pg` 1.6 | 4-database layout in production (primary/cache/queue/cable) sharing one `DATABASE_URL` | `config/database.yml` |
| Dev/Staging host | `192.168.100.186:5432` (default) | Postgres runs in Docker; db.yml default port is `5432`, overridable via `CLAWTROLPLAYGROUND_DB_PORT` | `config/database.yml`, `docker-compose.yml` (db service `postgres:16-alpine`) |
| Cache store | Solid Cache | `:solid_cache_store` in production | `config/environments/production.rb` |
| Job backend | Solid Queue | `:solid_queue`, migrations in `db/queue_migrate` | `config/environments/production.rb`, `config/initializers/queue_orchestration.rb` |
| ActionCable | Solid Cable | migrations in `db/cable_migrate` | `config/database.yml` |
| Active Storage | local filesystem (`:local`) with `image_processing` 1.14 variants | `config/environments/production.rb` |

## Authentication & Security

| Concern | Choice | Notes | Source |
|---|---|---|---|
| Password hashing | bcrypt 3.1.20 (`has_secure_password`) | `Gemfile` |
| OAuth | omniauth 2.1.4 + omniauth-github 2.0.1 + omniauth-rails_csrf_protection 2.0.1 | GitHub provider gated on `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | `config/initializers/omniauth.rb` |
| Rate limiting | rack-attack 6.8.0 — authenticated 100 req/min, anon 20 req/min, write ops 30 req/min, task-creation 10 req/min; safelist for `192.168.100.0/24` and valid `CLAWTROL_API_TOKEN` / `CLAWTROL_HOOKS_TOKEN` bearers | `config/initializers/rack_attack.rb` |
| CSP | report-only, unsafe-inline for Stimulus/Turbo + Tailwind utility classes | `config/initializers/content_security_policy.rb` |
| Hooks auth | `HOOKS_TOKEN` / `CLAWTROL_HOOKS_TOKEN` shared secret for unauthenticated `/api/v1/hooks/*` endpoints; validated in `app/controllers/concerns/api/hook_authentication.rb` | `config/application.rb`, `config/initializers/hooks_token_validation.rb` |
| Telegram Mini App | HMAC-SHA256 initData validation (`TelegramInitDataValidator`, 5-min freshness) | `app/services/telegram_init_data_validator.rb` |
| SSRF | `SsrfProtection` concern blocks internal/private targets for saved-link fetcher | `app/jobs/process_saved_link_job.rb` |
| Credentials | `config/credentials.yml.enc` present (not read); `.env` + `.env.production.example` present (not read) | listed only |

## Background Jobs & Schedulers

Solid Queue adapter. Key jobs (see `app/jobs/`):

- `agent_auto_runner_job.rb` — wakes gateway users when tasks queued, honors nightly window 23:00–08:00 AR (`AUTO_RUNNER_NIGHT_START_HOUR`/`AUTO_RUNNER_NIGHT_END_HOUR` in `config/application.rb`)
- `factory_runner_job.rb`, `factory_runner_v2_job.rb`, `factory_cycle_timeout_job.rb`
- `nightshift_runner_job.rb`, `nightshift_timeout_sweeper_job.rb`
- `auto_validation_job.rb`, `run_validation_job.rb`, `run_debate_job.rb` (placeholder — real path is `DebateReviewService` via gateway)
- `catastrophic_guardrails_job.rb` — DB drop alerts (gated by `CLAWDECK_GUARDRAILS_ENABLED`; Telegram alerts via `CLAWTROL_TELEGRAM_BOT_TOKEN` + `CLAWTROL_TELEGRAM_ALERT_CHAT_ID`)
- `zeroclaw_auditor_*.rb`, `zeroclaw_dispatch_job.rb` — auditor subsystem
- `zerobitch_metrics_job.rb` — docker fleet metrics
- `transcript_capture_job.rb`, `transcript_retroactive_archive_job.rb`, `session_auto_linker_job.rb`
- `process_saved_link_job.rb` — Gemini CLI summarizer for saved links
- `daily_executive_digest_job.rb`, `daily_cost_snapshot_job.rb`, `process_recurring_tasks_job.rb`, `generate_diffs_job.rb`, `pipeline_processor_job.rb`, `auto_claim_notify_job.rb`, `openclaw_notify_job.rb`

Concurrency guardrails configured in `config/initializers/queue_orchestration.rb` via `AUTO_RUNNER_*` env vars (max concurrent day/night, cooldowns, per-model/provider inflight caps).

## HTTP Clients

| Client | Version | Usage |
|---|---|---|
| `Net::HTTP` (stdlib) | — | Dominant client: `app/services/openclaw_gateway_client.rb`, `openclaw_webhook_service.rb`, `external_notification_service.rb`, `agent_auto_runner_service.rb`, `pipeline/qdrant_client.rb`, `marketing_image_service.rb`, `social_media_publisher.rb` |
| faraday | 2.14.1 (>= for CVE-2026-25765) | Declared in `Gemfile`; no direct `Faraday.new` call sites in `app/` |
| httparty | 0.24.2 | Declared in `Gemfile`; no direct `HTTParty` call sites in `app/` |

## Real-time / File Watching

- `listen` 3.9.0 + `rb-inotify` 0.11.1 — `app/services/transcript_watcher.rb` singleton watches `~/.openclaw/agents/main/sessions/*.jsonl` and broadcasts via ActionCable. Initializer `config/initializers/transcript_watcher.rb` only starts it under Puma (not console/rake/test).
- ActionCable over Solid Cable (DB-backed), WebSocket connect-src allowlisted in CSP.

## Development & Test Tooling

- `bullet` (N+1 detection) — dev/test
- `debug` — dev/test
- `bundler-audit`, `brakeman` — security scans
- `rubocop-rails-omakase` — style
- `web-console`, `rails_live_reload`, `letter_opener` — dev only
- `capybara`, `selenium-webdriver`, `webmock` — test
- Postgres test DB defaults to `clawtrolplayground_test` (`config/database.yml`)

## Deployment Surfaces

- **Docker** (`Dockerfile`, `docker-compose.yml`) — app exposed on host port `4001` → container `3000`, bundled `postgres:16-alpine` as `db` service, volumes `pgdata` + `storage`, bridge network `clawdeck-network`.
- **Render** (`render.yaml`) — free plan web service + managed `clawdeck-db`; pulls `DATABASE_URL` from DB, `SOLID_QUEUE_IN_PUMA=1`, `RAILS_MASTER_KEY` / `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` marked `sync: false` (operator-set).
- **Production env** (`config/environments/production.rb`) — `force_ssl=false` / `assume_ssl=false` (local-network deployment), logs to STDOUT, health check `/up`, mailer host derived from `APP_BASE_URL` (fallback `localhost:4001`), Action Mailer SMTP.
- `Procfile.dev` + `bin/dev` for Foreman dev stack; `install.sh`, `start.sh` bootstrap scripts.
