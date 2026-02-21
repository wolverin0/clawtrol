# Task #258 — Task Modal Durability Implementation

Date: 2026-02-21
Repo: `/home/ggorbalan/clawdeck`

## Scope implemented

Implemented the durability items requested:

1. **Sidecar ingest during run**
2. **Backfill rake task**
3. **Strict task scope**
4. **Persisted timeline support in modal API response**
5. **Tests for ingestion + strict/persisted behavior**

---

## Changes made

### 1) Sidecar ingest during run (`agent_log` path)

**File:** `app/services/agent_log_service.rb`

- Added ingestion of parsed transcript messages into `agent_activity_events` on each `agent_log` call.
- Ingest is idempotent via existing unique index (`run_id`,`seq`) and ingestion service duplicate handling.
- `run_id` source priority:
  - `task.last_run_id`
  - `task.agent_session_id`
  - fallback `task-<id>`

This ensures activity is persisted even if watcher/stream timing is imperfect.

### 2) Persisted timeline support when transcript/session unavailable

**File:** `app/services/agent_log_service.rb`

- Added persisted fallback path:
  - If no valid scoped transcript is available, returns task-scoped sidecar events (`agent_activity_events`) instead of empty feed.
- Preserves strict scoping by task id only (no cross-task session fallback).
- Returns `persisted_count` in result for UI hints.

**File:** `app/controllers/api/v1/tasks_controller.rb`

- `agent_log` JSON now includes:
  - `persisted_count`

This unblocks the modal’s reconnect/empty-state logic and makes persisted history visible.

### 3) Strict task scope hardening

**File:** `app/models/agent_activity_event.rb`

- `for_task` scope now accepts either Task object or task id:
  - `AgentActivityEvent.for_task(task)`
  - `AgentActivityEvent.for_task(task.id)`

This avoids accidental broad queries and simplifies strict usage in services/tests.

### 4) Backfill rake task

**File:** `lib/tasks/agent_activity.rake`

Added:

- `rake agent_activity:backfill TASK_ID=... LIMIT=...`

Behavior:
- Reads transcript for tasks with `agent_session_id`
- Parses messages via `TranscriptParser`
- Ingests to sidecar with source `backfill`
- Reports per-task and aggregate created/duplicate counts

Existing prune task remains unchanged.

### 5) Tests

**Files:**
- `test/services/agent_activity_ingestion_service_test.rb`
- `test/services/agent_log_service_test.rb`

Added coverage for:
- ingestion normalization/defaults
- idempotent duplicate handling
- strict `for_task` scope behavior
- persisted-sidecar return when no session
- sidecar ingest during `agent_log` run path
- result struct includes `persisted_count`

---

## API/CLI evidence

### A) `agent_log` includes persisted metadata

Command:

```bash
source ~/.openclaw/.env
curl -sS -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
  "http://192.168.100.186:4001/api/v1/tasks/258/agent_log?since=0" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print({k:d.get(k) for k in ["has_session","persisted_count","total_lines","task_status"]});print("messages",len(d.get("messages",[])))'
```

Output:

```text
{'has_session': True, 'persisted_count': 2, 'total_lines': 2, 'task_status': 'in_progress'}
messages 2
```

### B) Backfill rake works and is idempotent

Command:

```bash
bundle exec rake agent_activity:backfill TASK_ID=258 LIMIT=1
```

Output:

```text
task=258 session=task-258-backfill lines=2 created=0 dup=2
Backfill complete: processed=1 created=0 duplicates=2
```

---

## Test output

Command:

```bash
bundle exec rails test \
  test/services/agent_activity_ingestion_service_test.rb \
  test/services/agent_log_service_test.rb
```

Output:

```text
Running 12 tests in a single process (parallelization threshold is 50)
Run options: --seed 19699

# Running:

............

Finished in 3.803482s, 3.1550 runs/s, 12.3571 assertions/s.
12 runs, 47 assertions, 0 failures, 0 errors, 0 skips
```

---

## Notes

- `POST /api/v1/hooks/agent_activity` route does not exist in current routes table in this app instance; durability implementation therefore relies on:
  - transcript watcher path (already present)
  - **new `agent_log` ingest during run**
  - **new backfill rake**
- No schema migration required for this patch.
