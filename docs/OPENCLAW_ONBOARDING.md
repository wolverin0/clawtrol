# OpenClaw Onboarding and Self-Heal

This guide defines the production contract between OpenClaw (orchestrator) and ClawTrol (mission-control UI/state).

## 1) Source of truth

- OpenClaw owns orchestration and execution.
- ClawTrol owns task state, visibility, history, and reporting UI.
- Do not treat "task moved" as "task reported". Reporting is mandatory.

## 2) Required callbacks (every run)

For every completed run, call both hooks in this exact order:

1. `POST /api/v1/hooks/task_outcome`
2. `POST /api/v1/hooks/agent_complete`

Rules:
- `task_outcome` must always include `needs_follow_up` (`true` or `false`).
- If follow-up is needed, set `recommended_action` to `requeue_same_task` and include `next_prompt`.
- If follow-up is not needed, set `recommended_action` to `in_review`.
- `agent_complete` must include findings (and session/output files when available).

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
