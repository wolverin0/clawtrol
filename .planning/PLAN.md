# Factory Engine v1 — Implementation Plan

## Milestone: Factory loops actually RUN when you press Play

## Wave 1 (parallel — no dependencies)

### Task A: Schema + Models + Service
**Files to create/modify:**
- `db/migrate/XXXX_add_factory_engine_columns.rb` (NEW)
- `app/models/factory_loop.rb` (MODIFY)
- `app/models/factory_cycle_log.rb` (MODIFY)
- `app/services/factory_engine_service.rb` (NEW)
- `app/jobs/factory_runner_job.rb` (NEW)
- `app/jobs/factory_cycle_timeout_job.rb` (NEW)

**What to do:**
1. Migration: add `consecutive_failures` (int, default 0) to factory_loops. Add `openclaw_session_key` (string) to factory_cycle_logs. Add `pending` and `timed_out` to cycle_log statuses.
2. FactoryEngineService:
   - `start_loop(loop)` — enqueue RecursiveFactoryJob
   - `stop_loop(loop)` — dequeue pending jobs for this loop
   - `record_cycle_result(cycle_log, status:, summary:, tokens:)` — update log, reset/increment failures, auto-pause at 5
3. FactoryRunnerJob:
   - `perform(loop_id)` — load loop, return if not playing, create CycleLog(pending), wake OpenClaw via OpenclawWebhookService, enqueue TimeoutJob, re-enqueue self with `set(wait: loop.interval_ms.milliseconds)`
4. FactoryCycleTimeoutJob:
   - `perform(cycle_log_id)` — if still pending/running after timeout, mark timed_out, increment failures

**Verify:**
- `bin/rails db:migrate` succeeds
- `FactoryLoop.new.respond_to?(:consecutive_failures)` → true
- `FactoryRunnerJob.perform_now(loop.id)` with a playing loop creates a CycleLog and doesn't crash

**Done when:**
- Migration applied, models updated, service + 2 jobs exist and are loadable

---

### Task B: Model Callbacks (play/pause/stop → engine)
**Files to modify:**
- `app/models/factory_loop.rb`
- `app/controllers/factory_controller.rb`

**What to do:**
1. `after_commit` on status change:
   - `playing` → `FactoryEngineService.new.start_loop(self)`
   - `paused`/`stopped`/`error` → `FactoryEngineService.new.stop_loop(self)`
2. Update `play!` to also set `last_cycle_at: nil` (fresh start)
3. Controller `play`/`pause`/`stop` actions already call model methods — no change needed

**Depends on:** Task A (needs FactoryEngineService to exist)

**Verify:**
- Press Play on a loop via UI → `SolidQueue::Job` created for FactoryRunnerJob
- Press Pause → job dequeued (or next run skips because status != playing)

**Done when:**
- Play/pause/stop trigger engine start/stop correctly

---

## Wave 2 (after Wave 1)

### Task C: Cycle Results Webhook
**Files to create/modify:**
- `app/controllers/api/v1/factory/cycles_controller.rb` (NEW)
- `config/routes.rb` (MODIFY — add route)

**What to do:**
1. POST `/api/v1/factory/cycles/:id/complete` endpoint
   - Auth: Bearer token (same as existing API auth)
   - Body: `{ status: "completed"|"failed", summary: "...", input_tokens: N, output_tokens: N, model_used: "..." }`
   - Calls `FactoryEngineService.record_cycle_result`
2. Add route to existing API namespace

**Verify:**
- `curl -X POST .../api/v1/factory/cycles/1/complete -d '{"status":"completed","summary":"test"}' -H "Authorization: Bearer $TOKEN"` → 200

**Done when:**
- Endpoint exists, updates cycle log, resets/increments failure counter

---

### Task D: System Prompts for Loops (independent — can run anytime)
**Files to create:**
- `db/seeds/factory_loops.rb` or rake task

**What to do:**
- Define 12 loop configurations with proper system_prompts, models, intervals
- Seed or create via UI

**Done when:**
- 12 loops exist in DB with meaningful system_prompts

---

## Execution Order
```
Wave 1: [Task A] ──────────────────────┐
                                        ├─→ Wave 2: [Task C] → [VERIFY] → [SHIP]
Wave 1: [Task B depends on A, so A→B] ─┘
Wave *: [Task D] ──── independent ──────────────────────────→
```

Actually: A → B → C sequential (each depends on previous). D is independent.

## OpenClaw Wake Message Format
```
Factory cycle ##{cycle_log.id} for loop "#{loop.name}".
Model: #{loop.model}
System prompt: #{loop.system_prompt}
Report results to: POST #{base_url}/api/v1/factory/cycles/#{cycle_log.id}/complete
```

## Auto-pause Logic
```ruby
if cycle failed/timed_out:
  loop.increment!(:consecutive_failures)
  loop.increment!(:total_errors)
  if loop.consecutive_failures >= 5:
    loop.update!(status: "error")
    # Telegram notification
else:
  loop.update!(consecutive_failures: 0)
  loop.increment!(:total_cycles)
```
