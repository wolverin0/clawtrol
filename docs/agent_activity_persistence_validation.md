# Agent Activity Persistence Validation

## Goal
Prove task activity remains visible after transcript/session cleanup.

## Steps
1. Create or use an existing task in `in_progress`.
2. Ingest activity events:
   ```bash
   curl -s -X POST "$BASE/api/v1/hooks/agent_activity" \
     -H "X-Hook-Token: $CLAWTROL_HOOKS_TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"task_id":123,"events":[{"run_id":"run-demo","seq":1,"event_type":"heartbeat","source":"orchestrator","level":"info","message":"run started"},{"run_id":"run-demo","seq":2,"event_type":"tool_call","source":"orchestrator","level":"info","message":"Calling read","payload":{"tool_name":"read"}}]}'
   ```
3. Verify API returns persisted events:
   ```bash
   curl -s "$BASE/api/v1/tasks/123/agent_log" -H "Authorization: Bearer $CLAWTROL_API_TOKEN"
   ```
4. Simulate transcript cleanup by removing/renaming the session JSONL file in `~/.openclaw/agents/main/sessions`.
5. Re-run `agent_log` request from step 3.
6. Expected: same persisted events are still returned (`persisted_count > 0`), no blind waiting state in UI.

## Optional prune check
- Default is keep forever.
- Prune manually only when requested:
  ```bash
  bundle exec rake agent_activity:prune DAYS=60
  ```
