# ZeroClaw Auditor Gate

Date: 2026-02-23
Scope: ClawTrol QA gate between executor output and final completion.

## What It Does

When an agent task enters `in_review`, an auditor evaluates output quality and emits one of:
- `PASS`
- `FAIL_REWORK`
- `NEEDS_HUMAN`

The auditor writes:
- `review_type = auditor`
- `review_status = passed|failed`
- `review_result["auditor"]` with verdict, score, checks, fixes, proof
- `state_data["auditor"]` with rework counter + history
- `## Auditor Verdict` section appended to task description

## Triggers

Implemented triggers:
1. **Automatic event trigger**
   - Hook: `Task` status transition to `in_review`
   - Condition: task is agent-assigned and auditable by tag/pipeline type
   - Mechanism: `ZeroclawAuditorJob.perform_later(task_id, trigger: "status_transition")`
2. **Manual API trigger**
   - `POST /api/v1/tasks/:id/run_auditor`
3. **Webhook trigger**
   - `POST /api/v1/hooks/zeroclaw_auditor`
   - Auth: `X-Hook-Token`
   - Intended for external orchestrators that want explicit re-audit enqueue.
4. **Cron sweep trigger**
   - `bin/rake zeroclaw:auditor_sweep[limit,force,min_interval_seconds,lookback_hours]`
   - Scans `in_review` + `assigned_to_agent` tasks and enqueues auditor jobs.

Not implemented:
- Filesystem folder scanner trigger.

## State Transitions

- `PASS`
  - Keeps task in `in_review` by default.
  - Optional auto-done via env flag.
- `FAIL_REWORK`
  - Moves task to `in_progress`.
  - Increments `state_data.auditor.rework_count`.
- `NEEDS_HUMAN`
  - Keeps task in `in_review`.
  - Emits job alert notification.

## Anti-Loop and Dedup Guards

- Rework loop guard:
  - `ZEROCLAW_AUDITOR_MAX_REWORK_LOOPS` (default `2`)
  - After threshold, repeated failures escalate to `NEEDS_HUMAN`.
- Trigger dedupe guard (webhook/cron only):
  - `ZEROCLAW_AUDITOR_MIN_INTERVAL_SECONDS` (default `300`)
  - Recent audited tasks are skipped for webhook/cron re-triggers unless `force=true`.

## LLM Strategy

Current mode: `rule_based` (deterministic checks, no external LLM call).

Configured model metadata for future LLM-assisted mode:
- default: `openai-codex/gpt-5.3-codex`
- env: `ZEROCLAW_AUDITOR_MODEL`

Recommended rollout:
1. Keep `rule_based` as hard gate baseline.
2. Add optional LLM-assisted second pass only for borderline scores (50-84).
3. Keep final verdict deterministic when evidence is missing.

## Can ZeroClaws Talk to Each Other?

Yes, with two patterns:
1. **Current implemented pattern (recommended)**
   - Agents communicate through task artifacts (`description`, `output_files`, `review_result`, `state_data`).
   - Auditor reads executor output from task data.
2. **Direct inter-agent messaging (future)**
   - Possible via gateway channels, but increases coupling and debugging complexity.
   - Keep task-centric evidence as source of truth for reliability.

## Checklist Profiles

Files:
- `config/auditor-checklists/default.yml`
- `config/auditor-checklists/coding.yml`
- `config/auditor-checklists/research.yml`
- `config/auditor-checklists/infra.yml`
- `config/auditor-checklists/report.yml`

## Config

- `ZEROCLAW_AUDITOR_ENABLED` (default `true`)
- `ZEROCLAW_AUDITOR_AUTO_DONE` (default `false`)
- `ZEROCLAW_AUDITOR_MAX_REWORK_LOOPS` (default `2`)
- `ZEROCLAW_AUDITOR_TAGS` (default `coding,research,infra,report`)
- `ZEROCLAW_AUDITOR_MODE` (default `rule_based`)
- `ZEROCLAW_AUDITOR_MODEL` (default `openai-codex/gpt-5.3-codex`)
- `ZEROCLAW_AUDITOR_MIN_INTERVAL_SECONDS` (default `300`)
- `ZEROCLAW_AUDITOR_SWEEP_LIMIT` (default `100`)
- `ZEROCLAW_AUDITOR_SWEEP_LOOKBACK_HOURS` (default `168`)

## Reporting

- Weekly summary:

```bash
bin/rake zeroclaw:auditor_report[7]
```

- Sweep enqueue summary:

```bash
bin/rake zeroclaw:auditor_sweep[50,false,300,168]
```

Both commands print counters and can be used in cron/systemd schedules.
