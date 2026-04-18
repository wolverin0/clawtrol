# ClawTrol — Audit Remediation Roadmap

**Source:** `docs/audit/2026-04-17/AUDIT.md` + `FIX_PROMPTS.md`
**Branch:** `audit/2026-04-17-fixes` (off `audit/2026-04-17`)
**Strategy:** Phased, atomic, reversible. Parallel where independent, serial where state-coupled.
**Rollback policy:** every phase must leave the system in a working state or revertable via `git revert <sha>` + restore the `.bak` of any file it touched outside git (`systemd`, `/etc/clawtrol/`).

---

## Phase map

```
           P0 (serial)          P3 (parallel)                 P4 (serial)           P5
┌────────────────────────────┐  ┌──────────────┐    ┌────────────────────────┐   ┌─────┐
│  0.1 branch + tag snapshot │──▶ 3.1 pipeline │──┐ │                        │   │ 5.1 │
│  1.1 systemd PIDFile fix   │  │ 3.2 webhook  │  │ │ 4.1 DB role downgrade  │──▶│ test│
│  2.1 secrets envfile       │  │ 3.3 budget   │  ├▶│ 4.2 hardcoded IPs      │──▶│ 5.2 │
│  2.2 HOOKS_TOKEN + rotate  │  │ 3.4 cleanup  │  │ │                        │   │smoke│
└────────────────────────────┘  └──────────────┘  │ └────────────────────────┘   │ 5.3 │
                                                  │                              │push │
                                                  └──────────────────────────────▶     │
                                                                                 └─────┘
```

Legend: `──▶` = blocks, must complete before next column runs.

---

## Phase 0 — Safety prep  *(serial, coordinator-led)*

Prerequisite for every phase. Nothing is irreversible yet.

| id  | step | owner | blocks |
|-----|------|-------|--------|
| 0.1 | Create branch `audit/2026-04-17-fixes` off `audit/2026-04-17`, push | coordinator | all |
| 0.2 | Tag `pre-audit-fixes` on current `audit/2026-04-17` HEAD as rollback anchor | coordinator | all |
| 0.3 | Back up `~/.config/systemd/user/clawtrol.service` → `clawtrol.service.bak` | coordinator | 1.1 |
| 0.4 | Back up any existing `~/clawdeck/.env` (if present) | coordinator | 2.1 |

---

## Phase 1 — Revive production  *(serial, coordinator-led)*

Only after Phase 0. Unblocks every other phase.

| id  | step | file(s) | verify | rollback |
|-----|------|---------|--------|----------|
| 1.1 | FIX #1: `Type=simple`, drop `-d`, remove `PIDFile`, simplify `ExecStop` | `~/.config/systemd/user/clawtrol.service` | `curl localhost:4001/up` → 200 × 3 with 2s gap; `NRestarts` < 2 | `cp .bak back && daemon-reload && restart` |

**Blocker for:** all downstream phases (cannot test any fix against a dead app).

---

## Phase 2 — Secret hardening  *(serial, coordinator-led, after Phase 1)*

Not parallelized because both touch the running service's environment.

| id  | step | files | verify | rollback |
|-----|------|-------|--------|----------|
| 2.1 | FIX #2: create `/etc/clawtrol/clawtrol.env` (0640, root:ggorbalan), move `SECRET_KEY_BASE`, `DATABASE_URL`, `RAILS_*`, `APP_BASE_URL` into it; unit uses `EnvironmentFile=` | `/etc/clawtrol/clawtrol.env`, systemd unit | `curl /up` 200; `systemctl show --property=Environment` no SECRET_KEY_BASE; `sudo -u nobody cat` → Permission denied | revert unit + delete envfile |
| 2.2 | FIX #4: generate `HOOKS_TOKEN` via `openssl rand -hex 32`, add to envfile, restart | `/etc/clawtrol/clawtrol.env` | startup log no longer emits `[SECURITY] HOOKS_TOKEN ... not set`; `curl -X POST /api/v1/hooks/agent_complete` without token → 401; with valid token → 404/400 (not 401) | unset env var + restart |
| 2.3 | **(optional, requires operator consent)** Rotate `SECRET_KEY_BASE` via `bundle exec rails secret`; overwrite envfile; restart → invalidates all sessions (single-operator — re-login) | `/etc/clawtrol/clawtrol.env` | `/up` 200; login page works; old session cookie → 401 | restore old value |

**Decision gate for 2.3:** skip unless the current `SECRET_KEY_BASE` has been materially exposed. The audit flagged it was readable from `/proc/<pid>/environ`, so yes — rotate.

**Blocker for:** 4.1 (DB role downgrade needs the new envfile to own the new `DATABASE_URL`).

---

## Phase 3 — Independent Rails fixes  *(PARALLEL, 4 teammates)*

After Phase 1. These agents write code; no two touch overlapping files. All migrations are *created but not applied* — migration execution is serialized in Phase 4.

| id  | step | files touched | owner (teammate) | blocks |
|-----|------|---------------|-------------------|--------|
| 3.1 | FIX #3: `PipelineController` inherits `BaseController`; remove local auth | `app/controllers/api/v1/pipeline_controller.rb` | `rails-auth` | 5.1 |
| 3.2 | FIX #5: webhook idempotency — migration (unapplied), `Api::WebhookIdempotency` concern, wrap `hooks_controller#agent_complete` + nightshift hooks | `db/migrate/YYYYMMDDHHMMSS_add_event_dedup_to_webhook_logs.rb`, `app/controllers/concerns/api/webhook_idempotency.rb`, `app/controllers/api/v1/hooks_controller.rb`, `app/controllers/api/v1/nightshift_controller.rb` | `rails-hooks` | 4.0, 5.1 |
| 3.3 | FIX #7: budget gate — migration (unapplied), `User#over_budget?`, `enforce_budget_gate` in Tasks/FactoryLoops/Nightshift spawn actions | `db/migrate/YYYYMMDDHHMMSS_add_budget_cap_to_users.rb`, `app/models/user.rb`, `app/controllers/api/v1/tasks_controller.rb` (concern or inline), `app/controllers/api/v1/factory_loops_controller.rb`, `app/controllers/api/v1/nightshift_controller.rb` | `rails-budget` | 4.0, 5.1 |
| 3.4 | Small cleanups (5 files): Gemfile unused gems, Dockerfile ruby 3.3.8, rack_attack header-bypass line, delete orphan `config/credentials.yml.enc`, rename `config/application.rb` module | `Gemfile`, `Gemfile.lock`, `Dockerfile`, `config/initializers/rack_attack.rb`, `config/credentials.yml.enc` (delete), `config/application.rb` | `cleanup` | 5.1 |

**Conflict-free file map** — no two parallel tasks edit the same file:
- 3.1: pipeline_controller.rb only
- 3.2: hooks_controller.rb + nightshift_controller.rb + new files
- 3.3: tasks_controller.rb + factory_loops_controller.rb + user.rb + new files
- 3.4: Gemfile + Dockerfile + rack_attack.rb + credentials.yml.enc + application.rb

3.2 and 3.3 both edit `nightshift_controller.rb` → **serialize** 3.3 after 3.2, OR have 3.3 skip nightshift and add it as a follow-up. **Decision: 3.3 skips `nightshift_controller.rb`**, documents a follow-up task for me to merge after both land.

---

## Phase 4 — Post-parallel integration  *(serial, coordinator-led, after Phase 2 + Phase 3)*

| id  | step | verify | rollback |
|-----|------|--------|----------|
| 4.0 | Run `bundle exec rails db:migrate RAILS_ENV=production` | `db:migrate:status` shows the 2 new migrations as `up` | `db:rollback STEP=2` |
| 4.1 | FIX #6: create `clawtrol_app` Postgres role, grant DML + schema, update `DATABASE_URL` in `/etc/clawtrol/clawtrol.env` | `curl /up` 200; `psql -U clawtrol_app -c "CREATE EXTENSION ..."` → permission denied | revert envfile, keep role for re-try |
| 4.2 | Centralize hardcoded IPs: introduce `Rails.application.config.x.openclaw.gateway_url` etc., wire from env, replace 5 hardcoded `192.168.100.186` sites | `/up` 200; pipeline calls still succeed | revert commit |
| 4.3 | Merge the 3.3 nightshift budget-gate follow-up on top of 3.2 | nightshift create_mission refuses over-budget users | revert commit |

---

## Phase 5 — Verification & ship  *(serial)*

| id  | step | evidence |
|-----|------|----------|
| 5.1 | `bin/rails test` full suite on VM | summary: F=0, E=0 (or documented skips) |
| 5.2 | Smoke tests: `/up` 200 · `/health` 200 · `/api/v1/tasks` with token → 200 · `/api/v1/hooks/agent_complete` with idempotency-id repeat → single event row · budget-gate 402 on over-budget user | manual log |
| 5.3 | Squash-free commit push to `audit/2026-04-17-fixes`; open PR vs `main` on GitHub | PR URL |

---

## Non-goals (this roadmap explicitly does not)

- Split `app/controllers/api/v1/tasks_controller.rb` (1000+ lines) — needs engineer sign-off.
- Move SolidQueue out of Puma — not yet load-critical.
- Rename application module `ClawDeck` → `Clawtrol` at scale — touches too many files, separate PR.
- Add Sentry / Avo / Flipper / OpenAPI — belongs to `FEATURE_IDEAS.md`, not remediation.
- Multi-tenant redesign of `FactoryAgent` / `LearningEffectiveness` scoping — product decision required.

---

## Risks by phase

| Phase | Worst case | Mitigation |
|-------|-----------|------------|
| 1     | systemd edit bricks boot | `.bak` file + `journalctl --user -u clawtrol -f` while restarting |
| 2.3   | All users logged out | Only 1 operator, acceptable |
| 4.0   | Migration fails halfway | Postgres DDL is transactional; rollback to anchor tag |
| 4.1   | App cannot connect to DB | Keep `postgres` superuser URL warm as fallback |
| 3.2–3.3 | Parallel migration timestamps collide | Agents generate sequentially (2s gap) or coordinator renames after |

---

## Team plan

- **coordinator** (me): Phase 0, 1, 2, 4, 5. Owns the VM / systemd / DB.
- **rails-auth** (teammate): Phase 3.1
- **rails-hooks** (teammate): Phase 3.2
- **rails-budget** (teammate): Phase 3.3
- **cleanup** (teammate): Phase 3.4

All teammates work over SSH against `/home/ggorbalan/clawdeck/` on the VM, on branch `audit/2026-04-17-fixes`. Each commits its own atomic change; coordinator pushes at end of Phase 5.
