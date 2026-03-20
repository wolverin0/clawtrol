# Orchestration Master Roadmap (Canonical)

Last update: 2026-02-24 11:05 ART
Status: ACTIVE (orchestration slice closed)
Canonical file: `docs/roadmaps/2026-02-23-orchestration-master-roadmap.md`
Full product canonical plan: `docs/roadmaps/2026-02-23-full-execution-plan.md`
Supersedes (for orchestration scope): `docs/roadmaps/2026-02-23-clawtrol-master-roadmap.md`

## North Star
Turn ClawTrol into a reliable orchestration platform where:
- `Swarm` decides and decomposes work,
- `Factory` executes at scale in safe playgrounds,
- `ZeroBitch` extends execution capacity beyond local subagent limits,
- merge is blocked unless validation gates pass.

## Scope (this execution)
- [x] 1. Establish a single canonical roadmap with live checkboxes.
- [x] 2. Implement `factoryctl` (clone/worktree/backlog runner CLI).
- [x] 3. Implement Swarm task contract (structured payload + persistence).
- [x] 4. Implement merge gate (hard validation before integration).
- [x] 5. Expand ZeroClaw auditor triggers (event + manual + webhook + cron).

## Workstream A - Roadmap + Docs Hygiene
- [x] Create orchestration-specific canonical roadmap.
- [x] Mark previous roadmap as superseded for orchestration-only scope.
- [x] Add implementation log artifact with command-level evidence.

## Workstream B - Factory Operations (`factoryctl`)
- [x] Add executable CLI `bin/factoryctl`.
- [x] Support repo clone/update into workspace.
- [x] Support git worktree creation per branch.
- [x] Support backlog runner: pick next item, mark progress, execute command, mark done.
- [x] Document usage and safety model (`docs/factory/FACTORYCTL.md`).

## Workstream C - Swarm Task Contract
- [x] Add contract builder/validator service (`app/services/swarm_task_contract.rb`).
- [x] Persist contract in launched task (`state_data` + `review_config`).
- [x] Include contract metadata in API/UI launch responses.
- [x] Add tests for contract generation and validation (`test/services/swarm_task_contract_test.rb`).
- [x] Document contract fields and lifecycle (`docs/AGENT_SWARM_TASK_CONTRACT.md`).

## Workstream D - Merge Gate
- [x] Add executable `bin/merge_gate`.
- [x] Gate includes lint, security, tests, zeitwerk and artifact report.
- [x] Integrate gate into factory cherry-pick verification path (`CherryPickService.verify_production!`).
- [x] Document gate profiles and artifact output (`docs/qa/MERGE_GATE.md`).

## Workstream E - ZeroClaw Auditor Gate (MVP)
- [x] Add checklist profiles (`config/auditor-checklists/*.yml`).
- [x] Add auditor service + config loader (`app/services/zeroclaw/*`).
- [x] Add async runner job (`app/jobs/zeroclaw_auditor_job.rb`).
- [x] Auto-trigger on task transition to `in_review` for auditable tasks.
- [x] Manual trigger endpoint (`POST /api/v1/tasks/:id/run_auditor`).
- [x] Add anti-loop guard (max 2 reworks default).
- [x] Add weekly metrics report task (`bin/rake zeroclaw:auditor_report[7]`).
- [x] Add operator documentation (`docs/qa/ZEROCLAW_AUDITOR_GATE.md`).

## Workstream F - ZeroClaw Auditor Trigger Expansion
- [x] Add auditable/recency helper (`app/services/zeroclaw/auditable_task.rb`).
- [x] Add cron sweep service (`app/services/zeroclaw/auditor_sweep_service.rb`).
- [x] Add sweep job (`app/jobs/zeroclaw_auditor_sweep_job.rb`).
- [x] Add webhook trigger (`POST /api/v1/hooks/zeroclaw_auditor`).
- [x] Add recency guard for webhook/cron re-triggers.
- [x] Add tests for webhook + sweep + dedupe.

## Exit Criteria
- [x] All 5 scope items checked.
- [x] New docs linked from canonical roadmap.
- [x] At least one test run for new Swarm contract service.
- [x] Merge gate script executed once (`quick`) with artifact produced.
- [x] Auditor trigger expansion validated with tests and routes.

## Validation Notes
- Merge gate execution artifact: `docs/artifacts/2026-02-23T16-27-27Z-merge-gate-quick.md`
- Current gate result on existing repo state: `FAIL` (pre-existing issues outside this scoped implementation)
  - RuboCop offenses in existing files.
  - Existing Brakeman warnings.
  - Existing failing tests:
    - `RuntimeEventsIngestionServiceTest#test_skips_codemap_events_from_persistence`
    - `RunDebateJobTest#test_marks_review_as_failed_with_not_implemented_message`
- Auditor trigger expansion tests:
  - `test/services/zeroclaw/auditor_sweep_service_test.rb`
  - `test/jobs/zeroclaw_auditor_job_dedupe_test.rb`
  - `test/controllers/api/v1/hooks_zeroclaw_auditor_test.rb`

## Notes
- Existing dirty worktree is respected. Changes in this execution are additive and isolated.
- Filesystem scanner trigger remains intentionally out of scope.


## 2026-02-24 Foundation Reset (OpenClaw <-> ClawTrol)

### Decisions Locked
- [x] OpenClaw decides execution model.
- [x] One board equals one project.
- [x] Default board execution mode is chain (auto-continue only through explicit roadmap/dependency order; stop on blockers/gates).
- [x] Agent persona is optional; router can auto-suggest by task type (architect/frontend/uiux/etc).
- [x] Parallel execution is enabled only when OpenClaw sends an explicit execution_directive (mode, DAG, max_parallel_agents).

### Workstream G - Contract Hardening (P0)
- [ ] G1. Introduce strict prompt/data split.
  - tasks.description: human brief only.
  - tasks.execution_prompt (new): LLM prompt.
  - task_runs.prompt_used (new): immutable snapshot of sent prompt.
- [ ] G2. Stop writing runtime output/activity/follow-up into tasks.description.
- [ ] G3. Spawn path reads prompt with deterministic precedence:
  - compiled_prompt -> execution_prompt -> original_description -> cleaned_description -> task.name.
- [ ] G4. Task modal separation:
  - Description (human), Execution Prompt (LLM), Summary (task_run), Transcript (activity log), Artifacts (files/events).
- [ ] G5. Add board-level execution setting manual|chain|autonomous (default chain for project boards).

### Acceptance Criteria (Foundation)
- [ ] New runs no longer inject Agent Output blocks into tasks.description.
- [ ] Each run stores prompt_used and summary separately.
- [ ] Summary panel reads latest task_run.summary instead of regex over description.
- [ ] A 5-task dependency chain can run end-to-end in chain mode without manual trigger unless blocked.

### Notes for Ongoing Modal Debate
- Current modal still treats description as both notes and output source.
- New modal must expose operator intent separately from agent execution material.

### Modal Decisions Locked (2026-02-24)
- [x] Execution Prompt is editable.
- [x] Model is OpenClaw-decided, but manual override is allowed only before first run starts.
- [x] Persona is optional; explicitly assign when task type is strongly specialized.
- [x] Board execution mode (manual|chain|autonomous) must be visible in modal.
- [x] Summary tab must show the final task output (not mixed notes/runtime fragments).
- [x] Agent Activity must show full execution trace: input prompt, reasoning stream (when available), tool calls, tool results, and final report.

### Observability Requirements (P0)
- [ ] Persist exact prompt_used for every run.
- [ ] Persist model_selected + model_applied + routing reason.
- [ ] Persist persona resolution details (persona_id, source=explicit|auto, confidence).
- [ ] Keep append-only run timeline with hook timestamps and status transitions.
