# OpenClaw Onboarding and Self-Heal

This guide defines the production contract between OpenClaw (orchestrator) and ClawTrol (mission-control UI/state).

## 1) Source of truth

- OpenClaw owns orchestration and execution.
- ClawTrol owns task state, visibility, history, and reporting UI.
- Do not treat "task moved" as "task reported". Reporting is mandatory.

### P0 Data Contract (Feb 2026)

**Agent output goes to `task_runs` table, NOT `tasks.description`.**

| Field | Table | Purpose |
|-------|-------|---------|
| `description` | `tasks` | Human task brief only. NEVER write agent output here. |
| `agent_output` | `task_runs` | Agent findings per execution run |
| `prompt_used` | `task_runs` | Immutable snapshot of the prompt used |
| `agent_activity_md` | `task_runs` | Activity markdown log |
| `follow_up_prompt` | `task_runs` | Requeue instructions |

Both `task_outcome` and `agent_complete` hooks write to `task_runs` automatically.

## 2) Required callbacks (every run)

For every completed run, call both hooks in this exact order:

1. `POST /api/v1/hooks/task_outcome`
2. `POST /api/v1/hooks/agent_complete`

Rules:
- `task_outcome` must always include `needs_follow_up` (`true` or `false`).
- If follow-up is needed, set `recommended_action` to `requeue_same_task` and include `next_prompt`.
- If follow-up is not needed, set `recommended_action` to `in_review`.
- `agent_complete` must include findings (and session/output files when available).
- `session_id` should be the **plain UUID** of the transcript session (NOT the session key like `agent:main:subagent:UUID`).
- If you send a prefixed `session_id`, ClawTrol extracts the UUID automatically.
- If no `session_id` is provided, ClawTrol scans recent transcripts for task references and auto-links.

## 2b) Session linking for live transcript

For the ClawTrol Transcript tab to show live agent activity, the task must be linked to a session:

**Option A (preferred):** Send `session_id` in the `agent_complete` hook:
```json
{
  "task_id": 454,
  "session_id": "81f82d21-0920-44f5-8a82-0839bed2f874",
  "findings": "Completed the task..."
}
```

**Option B:** Call `POST /api/v1/tasks/:id/link_session` after spawning:
```json
{
  "session_id": "81f82d21-0920-44f5-8a82-0839bed2f874",
  "session_key": "agent:main:subagent:81f82d21"
}
```

**Option C (automatic):** If neither A nor B happens, ClawTrol's `AgentLogService` scans recent transcript files (`~/.openclaw/agents/main/sessions/*.jsonl`) for task ID references and auto-links the first match. This scan runs on every `agent_log` API call when no session is linked.

**Important:** The `session_id` must match a `.jsonl` filename in the sessions directory. OpenClaw's `session_key` (e.g., `agent:main:subagent:UUID`) is NOT the same as the transcript file UUID. Use `sessions_list` to get the real `sessionId` after spawning.

## 3) Follow-up policy (same-card, human approval)

Goal: avoid kanban bloat.

- Prefer same-task follow-up instead of creating sibling tasks.
- Requeue is explicit and approval-gated:
  - OpenClaw proposes follow-up in `task_outcome`.
  - Human approves in Telegram.
  - Then execute: `POST /api/v1/tasks/:id/requeue`.
- Without approval, keep task in `in_review`.

## 4) Nightly execution window

For Argentina operations, nightly work runs in:

- `23:00-08:00`
- Timezone: `America/Argentina/Buenos_Aires` (`UTC-3`)

Nightly tasks should also respect `nightly_delay_hours`.

## 5) Minimum endpoint set

- `GET /api/v1/tasks?status=up_next&assigned=true&blocked=false`
- `PATCH /api/v1/tasks/:id`
- `POST /api/v1/tasks/:id/requeue`
- `POST /api/v1/tasks/:id/link_session`
- `GET /api/v1/tasks/:id/agent_log`
- `POST /api/v1/hooks/task_outcome`
- `POST /api/v1/hooks/agent_complete`

## 6) Initial onboarding checklist

1. Copy prompt from `Settings -> Integration -> OpenClaw Install Prompt`.
2. Ensure API token and hooks token are loaded in OpenClaw runtime env.
3. Run one dry-run and verify both hooks are emitted.
4. Confirm task lands in `in_review` with visible outcome summary.
5. Confirm follow-up proposal shows `YES/NO` deterministically.

## 7) Self-heal routine

If behavior drifts, inject this instruction into OpenClaw memory/system files:

- OpenClaw is orchestrator; ClawTrol tracks state and reporting.
- Always call `task_outcome` then `agent_complete` for every run.
- Follow-up requires explicit human approval before requeue.
- Requeue same task (`/tasks/:id/requeue`) when follow-up is approved.
- Keep nightly gating fixed to `23:00-08:00` in Argentina timezone.

After self-heal, verify with:

1. One run with `needs_follow_up=false`.
2. One run with `needs_follow_up=true` and `requeue_same_task` suggestion.
3. Confirm no extra duplicate tasks were created for the same issue.
4. Confirm Transcript tab shows agent activity (session must be linked).
5. Confirm `tasks.description` was NOT modified by agent output.

## 8) Transcript visibility troubleshooting

If the Transcript tab shows "No agent activity":

1. **Check session_id:** `bin/rails runner "puts Task.find(ID).agent_session_id"`
   - If blank: session was never linked. Send `session_id` in hooks or call `link_session`.
   - If set: verify the transcript file exists at `~/.openclaw/agents/main/sessions/{session_id}.jsonl`.

2. **Check transcript file:**
   ```bash
   ls -la ~/.openclaw/agents/main/sessions/{session_id}.jsonl
   ```
   - If missing: the session UUID doesn't match a transcript file. Use `sessions_list` to find the real transcript UUID.

3. **Force auto-discovery:**
   ```bash
   bin/rails runner "
     task = Task.find(ID)
     task.update_column(:agent_session_id, nil)  # clear stale link
     svc = AgentLogService.new(task)
     result = svc.call
     puts 'has_session: ' + result[:has_session].to_s
     puts 'session_id: ' + task.reload.agent_session_id.to_s
   "
   ```
   This triggers `scan_recent_transcripts_for_task!` which searches recent `.jsonl` files for task references.

4. **Common session_id format issues:**
   - `agent:main:subagent:UUID` — ClawTrol extracts UUID automatically since Feb 2026
   - Transcript file UUID ≠ subagent process UUID — always use `sessions_list` to get the real ID
