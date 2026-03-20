> Status Update (2026-02-23 13:20 ART): This roadmap is superseded for orchestration scope by docs/roadmaps/2026-02-23-orchestration-master-roadmap.md.

# ClawTrol Master Roadmap (Legacy for Orchestration)

Last update: 2026-02-23 07:44 ART
Status: LEGACY (Superseded for orchestration scope)
Canonical file for orchestration: docs/roadmaps/2026-02-23-orchestration-master-roadmap.md
Supersedes: docs/roadmaps/2026-02-22-openclaw-clawtrol-memu-plan.md (historical)

## Scope
- Stabilize ClawTrol runtime UX and close DELTA/HARDEN tasks.
- Keep docs focused and reduce operator confusion.
- Leave external benchmark ingestion staged and explicit.

## Completed (this execution window)
- [x] #418 moved to `done` (implementation cards consolidated).
- [x] #419 moved to `done`: token governance depth hardening shipped (`/tokens` + analytics breakdowns by session/agent/task).
- [x] #420 moved to `done`: federated search depth hardening shipped (tasks/outputs/sessions/token-usage/notifications + board filter).
- [x] #421 moved to `done`: delivery target resolution stabilized (canonical resolver + origin routing metadata).
- [x] #422 moved to `done`: CSP report-only policy updated and applied in runtime.
- [x] `clawdeck-web.service` restarted so CSP initializer changes took effect.
- [x] Playwright validation:
  - [x] `boards/1` loads with no console errors/warnings.
  - [x] Data menu no longer shows `Self-Audit` or `Showcase`.
  - [x] `nightshift` route renders full content (no "content missing").
- [x] Rails verification:
  - [x] service tests for delivery resolver + notification/origin delivery passed.
  - [x] `bin/rails zeitwerk:check` passed.

## Documentation cleanup
- [x] Declared this file as single source of truth for roadmap status.
- [x] Marked legacy roadmap as superseded (kept for historical context).
- [x] Operational docs placement:
  - Canonical roadmap: `docs/roadmaps/`
  - Execution evidence: `docs/reports/`
  - Handoff context: `handoff.md`

## Remaining backlog (not blocked by current runtime fixes)
- [ ] External repo benchmark expansion beyond current `~/gitclone/openclaw` (sessions/token orchestration patterns from additional repos).
- [ ] Structured comparison matrix (what to adopt / reject / defer) across cloned repos.
- [ ] Prompts consolidation file (single prompts baseline + governance rules) linked to task templates.

## Next execution order
1. Clone missing benchmark repos into `~/gitclone/`.
2. Publish comparison matrix under `docs/reports/`.
3. Convert accepted patterns into scoped implementation tasks (small, reversible).
