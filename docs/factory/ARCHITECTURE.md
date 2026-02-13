# Agent Factory — Architecture Design

> Perpetual agent loops that run every X minutes, maintain state between cycles, and produce continuous output. Nightshift's big brother.

## Overview

| Concept | Nightshift | Agent Factory |
|---------|-----------|---------------|
| Cadence | Nightly | Every N minutes (15, 30, 60…) |
| Lifecycle | One-shot per night | Perpetual until paused/stopped |
| State | None (result text) | JSONB persisted between cycles |
| Scheduling | Manual arm in UI | OpenClaw cron (auto-synced) |
| Output | Single result blob | Cycle log per run + metrics |

---

## DB Schema

### `factory_loops` — Loop definitions

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint PK | |
| `name` | string, NOT NULL | e.g. "Personal COO" |
| `slug` | string, NOT NULL, UNIQUE | e.g. "personal-coo" |
| `description` | text | |
| `icon` | string | Default "🏭" |
| `status` | string, NOT NULL | `idle` / `playing` / `paused` / `stopped` / `error` |
| `interval_ms` | integer, NOT NULL | Milliseconds between cycles (900000 = 15min) |
| `model` | string, NOT NULL | Model identifier |
| `fallback_model` | string | If primary hits rate limit |
| `system_prompt` | text | The full system prompt for this loop |
| `state` | jsonb, NOT NULL, DEFAULT `{}` | Persisted state between cycles |
| `config` | jsonb, NOT NULL, DEFAULT `{}` | Static config (repos list, API URLs, etc.) |
| `metrics` | jsonb, NOT NULL, DEFAULT `{}` | Aggregated metrics |
| `openclaw_cron_id` | string | ID of the synced OpenClaw cron |
| `openclaw_session_key` | string | Session key for the agent |
| `last_cycle_at` | datetime | |
| `last_error_at` | datetime | |
| `last_error_message` | text | |
| `total_cycles` | integer, DEFAULT 0 | |
| `total_errors` | integer, DEFAULT 0 | |
| `avg_cycle_duration_ms` | integer | Rolling average |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Indexes:** `slug` (unique), `status`, `openclaw_cron_id`.

### `factory_cycle_logs` — Per-cycle execution history

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint PK | |
| `factory_loop_id` | bigint FK, NOT NULL | |
| `cycle_number` | integer, NOT NULL | Monotonically increasing per loop |
| `status` | string, NOT NULL | `running` / `completed` / `failed` / `skipped` |
| `started_at` | datetime, NOT NULL | |
| `finished_at` | datetime | |
| `duration_ms` | integer | |
| `model_used` | string | Actual model used (may be fallback) |
| `input_tokens` | integer | |
| `output_tokens` | integer | |
| `state_before` | jsonb | Snapshot of state at cycle start |
| `state_after` | jsonb | State after cycle completed |
| `summary` | text | Human-readable summary of what happened |
| `actions_taken` | jsonb, DEFAULT `[]` | Array of `{type, detail, timestamp}` |
| `errors` | jsonb, DEFAULT `[]` | Array of error objects |
| `created_at` | datetime | |

**Indexes:** `[factory_loop_id, cycle_number]` (unique), `[factory_loop_id, created_at DESC]`, `status`.

**Retention:** Keep 7 days of cycle logs. A nightly cleanup job purges older rows (or a Nightshift mission does it).

---

## API Endpoints

All under `/api/v1/factory/` with Bearer token auth (same as tasks API).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/loops` | List all loops (filterable by `status`) |
| GET | `/loops/:id` | Show loop with current state + last 10 cycles |
| POST | `/loops` | Create loop |
| PATCH | `/loops/:id` | Update loop config/prompt/interval |
| DELETE | `/loops/:id` | Delete loop + all cycle logs + remove cron |
| POST | `/loops/:id/play` | Start/resume loop → create/enable cron |
| POST | `/loops/:id/pause` | Pause loop → disable cron (state preserved) |
| POST | `/loops/:id/stop` | Stop loop → disable cron, reset state to `{}` |
| POST | `/loops/:id/trigger` | Force immediate cycle (skip waiting for cron) |
| GET | `/loops/:id/cycles` | Paginated cycle log history |
| GET | `/loops/:id/metrics` | Aggregated metrics + charts data |
| PATCH | `/loops/:id/state` | Manually edit persisted state (admin override) |

### UI Routes (Hotwire/Turbo)

| Path | View |
|------|------|
| `/factory` | Dashboard: all loops as cards with status, last cycle, sparkline |
| `/factory/:slug` | Detail: state inspector, cycle log timeline, metrics charts |
| `/factory/:slug/edit` | Edit form: prompt, config, interval, model |

---

## Cron Sync (Loop ↔ OpenClaw)

When a loop transitions to `playing`:

```bash
POST http://localhost:18789/api/schedules
Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN
Content-Type: application/json

{
  "name": "factory:personal-coo",
  "enabled": true,
  "schedule": {
    "kind": "every",
    "everyMs": 900000
  },
  "payload": {
    "kind": "agentTurn",
    "sessionKey": "agent:main:factory:personal-coo",
    "message": "FACTORY_CYCLE slug=personal-coo cycle={{cycle_number}}"
  }
}
```

- **Play:** `POST /api/schedules` (create) or `PATCH /api/schedules/:id` with `enabled: true`
- **Pause:** `PATCH /api/schedules/:id` with `enabled: false`
- **Stop:** `PATCH /api/schedules/:id` with `enabled: false` (+ reset state in DB)
- **Delete:** `DELETE /api/schedules/:id`
- **Store `openclaw_cron_id`** on the loop record after creation.

### Cycle Execution Flow

1. OpenClaw cron fires → sends `agentTurn` to session `agent:main:factory:{slug}`
2. Agent receives message containing `FACTORY_CYCLE slug=X`
3. Agent reads loop state from ClawTrol API: `GET /api/v1/factory/loops/:id`
4. Agent executes the loop's system prompt with current state + tools
5. Agent writes results back: `PATCH /api/v1/factory/loops/:id/state` + cycle log via `POST /api/v1/factory/loops/:id/cycles`
6. If cycle fails, agent sets `last_error_*` fields and increments `total_errors`

### Guard Rails

- **Overlap prevention:** If a cycle is already `running` (check `factory_cycle_logs` for `status=running` on this loop), skip and log as `skipped`.
- **Max consecutive errors:** After 5 consecutive failures, auto-pause the loop and notify via Telegram.
- **Timeout:** Each cycle has a max duration of `interval_ms * 0.8`. If exceeded, mark as failed.

---

## State Persistence Model

**Decision: JSONB column on `factory_loops.state`**

Why not a separate table or files:
- State is small (< 100KB per loop) — JSONB is fast and queryable
- Atomic updates with the loop record
- Cycle logs capture `state_before` / `state_after` for debugging/rollback
- No filesystem dependency = works in any deploy

### State Contract

Each loop defines its own state schema (documented in its prompt). The factory system treats state as opaque JSONB — only the loop's agent reads/writes it.

For rollback: admin can copy `state_before` from any cycle log back to `factory_loops.state` via the UI or API.

---

## Model Selection

| Loop | Primary Model | Fallback | Rationale |
|------|--------------|----------|-----------|
| Personal COO | `anthropic/claude-opus-4-6` | `google-gemini-cli/gemini-3-flash-preview` | Complex decision-making, drafting |
| Bug Hunter + QA | `openai-codex/gpt-5.3-codex` | `google-gemini-cli/gemini-3-flash-preview` | Code analysis, test writing |
| Research → Build | `anthropic/claude-opus-4-6` | `google-gemini-cli/gemini-3-flash-preview` | Evaluation + prototyping |

Model is stored per loop. Fallback triggers automatically when `model_limits` table shows the primary is rate-limited (reuse existing ClawDeck infrastructure).

---

## Metrics

### Per-Loop Metrics (stored in `factory_loops.metrics` JSONB)

```json
{
  "cycles_today": 42,
  "cycles_this_week": 294,
  "avg_duration_ms": 12500,
  "success_rate_7d": 0.97,
  "tokens_today": { "input": 150000, "output": 45000 },
  "tokens_this_week": { "input": 1050000, "output": 315000 },
  "last_10_durations": [12000, 13500, 11000, ...],
  "custom": { ... }
}
```

### Loop-Specific Custom Metrics

**Personal COO:**
```json
{
  "emails_processed": 156,
  "drafts_created": 23,
  "tasks_created": 12,
  "flags_active": 3,
  "invoices_flagged": 5
}
```

**Bug Hunter:**
```json
{
  "repos_scanned": 12,
  "tests_written": 47,
  "prs_opened": 8,
  "prs_merged": 5,
  "avg_coverage_delta": "+2.3%"
}
```

**Research → Build:**
```json
{
  "opportunities_evaluated": 34,
  "prototypes_built": 6,
  "validated": 4,
  "shipped": 2
}
```

### Display

- **Dashboard (`/factory`):** Cards per loop showing: status badge, last cycle time, success rate sparkline (last 24 cycles), key custom metric.
- **Detail (`/factory/:slug`):** Full metrics panel + cycle log timeline (Turbo Frame, lazy-loaded, paginated).
- Reuse ClawDeck's existing Chartkick/groupdate gems for sparklines if available, otherwise simple inline SVG sparklines.

---

## Initial Loop Configs

### 1. Personal COO

```yaml
slug: personal-coo
interval_ms: 900000  # 15 min
model: anthropic/claude-opus-4-6
config:
  gmail_account: ggorbalan@gmail.com
  clawtrol_api: http://192.168.100.186:4001/api/v1
  uisp_crm_api: https://192.168.2.197/crm/api/v1.0
  escalation_channel: telegram
```

### 2. Bug Hunter + QA

```yaml
slug: bug-hunter
interval_ms: 3600000  # 60 min
model: openai-codex/gpt-5.3-codex
config:
  repos_base: /mnt/pyapps
  repos:
    - personaldashboard
    - fitflow-pro-connect2
    - clawdeck
    # ... (12 repos)
  pr_target_branch: main
  max_prs_per_cycle: 2
```

### 3. Research → Build → Validate

```yaml
slug: research-build
interval_ms: 1800000  # 30 min
model: anthropic/claude-opus-4-6
config:
  clawtrol_api: http://192.168.100.186:4001/api/v1
  workspace: /home/ggorbalan/.openclaw/workspace/factory/prototypes
  max_prototypes_in_flight: 3
```
