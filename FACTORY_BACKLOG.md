# Factory Backlog ? ACTIVE (ClawTrol)

Updated: 2026-02-23
Scope: Execute only current ClawTrol priorities.
Rule: Pick first unchecked item top-to-bottom. One item per cycle.

## Active Queue (Execute First)

- [ ] Mission Control Health Dashboard
- [ ] Unified Navbar Registry (desktop + mobile parity)
- [ ] Dead/Empty Route Scanner (500, missing content, turbo frame mismatches, console errors)
- [ ] Error Inbox (Rails + Turbo + frontend aggregation)
- [ ] Roadmap Executor Sync (markdown checkboxes <-> board tasks)
- [ ] Burst Mode Control (`regular_tasks` vs `swarm_factory_zeroclaw`)
- [ ] Factory Promotion Gate (tests/lint/e2e before promote)
- [ ] Cross-Model Review Pipeline (implementer/reviewer/validator)
- [ ] Learning Inbox Wiring (self-audit/cognitive -> actions)
- [ ] Cognitive Core Sync (`mind/PROJECTS.md`, `DECISIONS.md`, `ERRORS.md`, daily logs)
- [ ] Runbook Generator (repeated incidents -> runbooks with owner/ETA)
- [ ] Daily Executive Digest (Telegram summary: done/failed/blocked/next 3)

## Guardrails

- Do not touch `/home/ggorbalan/clawdeck` directly from this loop.
- Work only in this workspace worktree.
- Never execute destructive DB commands (`db:drop`, `db:reset`, `db:purge`, `DROP DATABASE`, etc.).
- Mark [x] only after tests/validation pass.

## Legacy

Legacy backlog was archived to: `FACTORY_BACKLOG_ARCHIVE_2026-02-23.md`
