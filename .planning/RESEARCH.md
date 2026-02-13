# Factory Engine — Research

## Current State

### What exists
- **FactoryLoop model** (`app/models/factory_loop.rb`): CRUD + `play!`/`pause!`/`stop!` — only set DB status
- **FactoryCycleLog model** (`app/models/factory_cycle_log.rb`): belongs_to loop, tracks cycles
- **FactoryController** (`app/controllers/factory_controller.rb`): HTML + JSON endpoints for UI
- **API controller** at `api/v1/factory/loops` (routes exist, controller missing — 404s)
- **UI**: Master-detail layout at `/factory` — functional
- **Schema columns already exist**: `openclaw_cron_id`, `openclaw_session_key`, `last_cycle_at`, `last_error_at`, `last_error_message`, `total_cycles`, `total_errors`, `avg_cycle_duration_ms`, `metrics` (JSONB)

### What's missing (THE ENGINE)
- No jobs in `app/jobs/factory*`
- No services in `app/services/factory*`
- `play!` sets status but triggers NOTHING
- `openclaw_cron_id` column exists but is never written to
- No webhook endpoint for cycle results

### Infrastructure available
- **Solid Queue**: Active, running via Puma plugin (dev) / systemd (prod)
- **recurring.yml**: Has `agent_auto_runner_tick` (every 1 min) as reference pattern
- **AgentAutoRunnerService**: Polls tasks, wakes OpenClaw — good reference for our pattern
- **OpenclawWebhookService**: Sends POST to `/hooks/wake` with Bearer auth — THIS is how we wake OpenClaw

## Architecture Decision (from 3-model debate)

**Approach C: Hybrid** — Rails schedules, OpenClaw executes

```
play! → RecursiveFactoryJob.perform_later(loop_id)
  → Create CycleLog (status: pending)
  → Wake OpenClaw (POST /hooks/wake with cycle context)
  → Enqueue FactoryCycleTimeoutJob(cycle_log_id, at: timeout)
  → Re-enqueue self with set(wait: interval_ms)

OpenClaw receives wake → runs agentTurn (isolated)
  → Agent executes system_prompt
  → Session completes → delivery webhook back to ClawTrol

ClawTrol receives result:
  → Update CycleLog (completed/failed)
  → Reset or increment consecutive_failures
  → Auto-pause at 5 failures
```

## Key Constraints

1. **Subagents CAN'T call hooks** — fire-and-forget + timeout watchdog
2. **OpenClaw cron `delivery`** can POST results back — use this OR a dedicated webhook
3. **Solid Queue `set(wait:)`** for recursive scheduling — proven pattern
4. **`openclaw_cron_id` column exists** — we can store correlation but use SQ for scheduling
5. Schema already has `consecutive_failures` equivalent via `total_errors` — but need consecutive tracking

## Missing Schema

Need to add:
- `factory_loops.consecutive_failures` (integer, default 0) — for auto-pause logic
- `factory_cycle_logs.status` needs `pending` and `timed_out` added to enum
- `factory_cycle_logs.openclaw_session_key` — for correlation

## Reference: How AgentAutoRunnerService wakes OpenClaw

```ruby
# OpenclawWebhookService#send_webhook
uri = URI.parse("#{user.openclaw_gateway_url}/hooks/wake")
request.body = { text: message, mode: "now" }.to_json
# Headers: Content-Type: application/json, Authorization: Bearer #{token}
```

This is the exact same mechanism we'll use for Factory cycles.
