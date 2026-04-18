# ClawTrol — Feature Proposals (additive, not in scope for FIX_PROMPTS)

**Scope:** not defect remediation — net-new capabilities the audit thinks are worth adding. Ranked roughly by ROI-per-week.
**Assumption:** all of these are done *after* the P0 fixes land. Do not build features on a crash-looping server.

---

## Tier 1 — High leverage, small effort

### F1. Cost alerts (Telegram DM + daily digest)

**Why:** Pairs with FIX #7. Even with a hard budget cap, silent spend between 0 and cap is invisible today. A morning digest ("last 24h: 12 tasks, $4.20, top model: GLM-4.7") fits the existing nightshift briefing pattern.

**How (1–2 days):**
- Extend `CostSnapshotService` with a daily rollup at 06:00 local (user TZ).
- New job `DailyCostDigestJob` → reads last 24h `token_usages`, renders to markdown, dispatches via existing Telegram client.
- Add `User.cost_digest_enabled` boolean + UI toggle in settings.
- Threshold-based: separate mid-day alert when spend crosses 50% / 75% / 100% of daily cap.

**Edge:** include OpenClaw gateway cost separately so user can see which models burned the budget.

### F2. `rswag` + published OpenAPI spec

**Why:** OpenClaw is the primary external consumer of `/api/v1/*`. Any drift between the two is a production incident. Generated spec = single source of truth + browsable docs at `/api-docs`.

**How (1 day):**
- Add `gem "rswag-api"`, `gem "rswag-ui"`, `gem "rswag-specs"`.
- Annotate 5–10 existing controller tests with `swagger_helper` blocks.
- Mount at `/api-docs`.
- CI job `rake rswag:specs:swaggerize` fails if spec is out of date.

### F3. Strong Migrations gem

**Why:** 167 migrations and growing. Adding a NOT NULL column to a large table without default will lock production. `strong_migrations` catches these at the migration-writing step, not after the outage.

**How (1 hour):**
- `gem "strong_migrations"`.
- `rails g strong_migrations:install`.
- Configure against Rails 8.1 + Postgres 16.

### F4. Admin dashboard via Avo (or Trestle)

**Why:** Handoff mentions ops are done via `rails console` + hand-written SQL. An operator-grade admin UI replaces that for common tasks (impersonate user, inspect API tokens, revoke session, purge webhook_logs).

**How (1 day):**
- `gem "avo"` → `rails g avo:install`.
- Generate resources for User, ApiToken, Session, Task, Board, NightshiftMission, WebhookLog.
- Mount at `/admin` behind `require_admin` filter.
- No write access outside current session.

### F5. Feature flags via Flipper

**Why:** As audit found, mid-flight refactors (pipeline v1→v2) coexist in prod. Flipper lets you gate the new path behind a per-user flag while the old path handles traffic.

**How (1 day):**
- `gem "flipper"`, `gem "flipper-active_record"`, `gem "flipper-ui"`.
- Mount UI at `/admin/feature_flags`.
- Wrap the `pipeline/*` divergence points in `Flipper.enabled?(:pipeline_v2, current_user)`.

---

## Tier 2 — Medium effort, high payoff

### F6. Multi-model debate view

**Why:** Already called out in handoff §11 roadmap. Use case: run the same prompt on Opus + Sonnet + GLM + GPT-5.4 Mini, show side-by-side diffs, let the operator pick the winner. Differentiator vs. plain kanban.

**How (1 week):**
- New model `Debate`: `belongs_to :task, has_many :debate_runs`.
- `DebateRun`: one per model with status, output, diff, cost.
- `POST /api/v1/tasks/:id/debates` kicks off N parallel `DispatchJob`s with different `routed_model`.
- UI: new tab on the task modal with a column per model, highlight diffs, pick-a-winner button that promotes that run's output as the task's official output.
- Cost gate: require cumulative spend of N models to fit under user's daily cap or refuse.

### F7. GitHub issue → task bridge

**Why:** Repo is already on GitHub; half your tasks probably exist as issues. Two-way sync avoids manual copy-paste.

**How (3 days):**
- OmniAuth GitHub scope expansion: `repo`.
- `GithubIssueSyncService` — on configured repos, periodic poll (SolidQueue recurring job) creates a ClawTrol task for each new `issue` with label `claw`.
- Reverse: `task.after_commit :sync_status_to_github` updates the linked issue's labels (`in_progress`, `in_review`, `done`) via Octokit.
- Map: GitHub comments → ClawTrol task comments (unidirectional for simplicity).

### F8. Transcript viewer: search + syntax highlighting

**Why:** Transcripts can be thousands of lines. Currently they render as plain text. Ctrl-F in the browser is the state of the art.

**How (3 days):**
- Client-side: `highlight.js` via importmap for code blocks in transcripts.
- Server-side: `pg_trgm` full-text search on `agent_activity_events.content` (already Postgres, add `CREATE EXTENSION pg_trgm` migration + GIN index).
- New endpoint `GET /api/v1/tasks/:id/transcript/search?q=...`.
- UI: Stimulus search box with debounced API call, scroll-to and highlight matches.

### F9. Backup automation + restore runbook

**Why:** No evidence of any backup today. Single Postgres Docker volume on a homeserver. If the VM dies or the docker volume corrupts, everything is gone.

**How (1 day):**
- `scripts/backup.sh`: pg_dump + rotation (keep 7 daily + 4 weekly + 12 monthly).
- Push to S3 / Backblaze / Hetzner Object Storage with client-side encryption (age).
- Cron via systemd-timer in user scope.
- `scripts/restore.sh`: documented quarterly drill.

---

## Tier 3 — Nice to have

### F10. Uptime monitoring

Hit `/up` from outside the LAN every minute (healthchecks.io, UptimeRobot, or Uptime Kuma on a second VM). Alert on 3 consecutive failures.

### F11. Webhook delivery log UI

Mount `WebhookLog` records at `/admin/webhooks` (via Avo from F4) with filtering by endpoint + event_id + status.

### F12. Keyboard-driven kanban

Hotwire-native shortcuts (j/k to move between cards, space to open, c to create, / to search). Make it feel like Linear.

### F13. Multi-operator mode (when you are ready)

Team spaces, per-space boards, per-space budgets, per-space API tokens. Requires the Pipeline-controller fix (FIX #3) landed first, plus row-level scope review of `FactoryAgent` + `LearningEffectiveness` models which are currently global.

---

## Out of scope (explicit)

- **Payment processing** — no revenue surface exists; adding Stripe / MercadoPago now would be security surface area without upside.
- **Kubernetes / K3s** — single-operator homeserver does not need it. Systemd is the right tool.
- **Event sourcing** — `AgentActivityEvent` is append-only which is close enough; do not introduce a full CQRS rewrite.

---

**End of feature proposals.**
