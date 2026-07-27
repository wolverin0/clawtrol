# ClawTrol Documentation Map
<!-- Covers document authority for the safe-LAN revival, deployment, recovery, and passive Hermes boundary. -->
<!-- Key terms: CURRENT, SUPERSEDED, ABANDONED, GENERATED, immutable SHA image, passive mirror. -->
<!-- Read this map before any documentation body; never execute a superseded runbook or roadmap. -->
<!-- CURRENT means authoritative only for the scope stated in its row, not a blanket release verdict. -->
<!-- The recovered Docker topology is current; systemd and source-pull deployment instructions are superseded. -->
<!-- Updated: 2026-07-27 with the personal control-room implementation contract. -->

## Current sources

| Document or artifact | Verdict | Scope |
|---|---|---|
| `AGENTS.md` | CURRENT | Repository workflow, safety boundaries, and merge gates. |
| `remediation-decisions.md` | CURRENT | Finding disposition and remediation/defer governance. |
| `docs/reports/clawtrol-revival-baseline-2026-07-26.md` | CURRENT | Recovery lineage; its original readiness verdict remains historical evidence. |
| `docs/reports/safe-lan-remediation-r0-2026-07-26.md` | CURRENT | Latest active-database, container, stopped-service, and health anchors. |
| `docs/reports/safe-lan-remediation-r1-r4-2026-07-27.md` | CURRENT | Credential cutover, immutable deployment, closed R1-R3 evidence, and remaining passive-mirror gates. |
| `docs/reports/hermes-delta-review-2026-07-26.md` | CURRENT | Passive-mirror boundary and pinned Hermes compatibility evidence. |
| `docs/plans/CLAWTROL-WEZBRIDGE-CONTROL-PLANE.md` | CURRENT | ClawTrol cockpit, outbound Wezbridge sync, operator intents, supervision, and exact-revision delivery contract. |
| `Dockerfile` and `docker-compose.yml` | CURRENT | Exact-SHA image and one-web-container deployment topology. |
| `.claude/skills/deploy-to-vm/SKILL.md` | CURRENT | Immutable release procedure and rollback gate. |
| `.claude/rules/local-first-workflow.md` | CURRENT | Local edit and immutable delivery policy. |
| `docs/API_REFERENCE.md` | CURRENT, LIMITED | Task-board API reference; disabled legacy execution sections are not authoritative. |

## Superseded or abandoned sources

| Document or group | Verdict | Replaced by |
|---|---|---|
| `docs/audit/2026-04-17/**` | SUPERSEDED | July revival reports and remediation decisions. Keep only as historical evidence. |
| `docs/audit/2026-04-17/RESTORE_RUNBOOK.md` | SUPERSEDED | R0 recovery anchors plus explicit isolated-restore evidence. Its old service topology must not be executed. |
| `docs/roadmaps/**` | SUPERSEDED | `remediation-decisions.md` and Beads phase graph. |
| `docs/STRATEGIC_ROADMAP.md` | SUPERSEDED | Safe-LAN scope and deferred review decisions. |
| `docs/OPENCLAW_INTEGRATION.md` and `docs/OPENCLAW_ONBOARDING.md` | ABANDONED | Direct OpenClaw execution is retired. |
| `docs/NIGHTSHIFT_ARCHITECTURE.md` | ABANDONED | Nightshift execution remains retired. |
| `docs/factory/**` | ABANDONED | Factory execution remains retired. |
| `docs/qa/DUAL_BACKEND_HERMES_TEST_PLAN.md` | SUPERSEDED | Passive Hermes mirror tests and schema fixtures. |
| `docs/qa/ZEROCLAW_AUDITOR_GATE.md` | ABANDONED | ZeroClaw execution remains retired. |
| `docs/zeroclaw-fleet-observability.md` | ABANDONED | ZeroBitch/ZeroClaw fleet control is outside the revived product. |
| `script/install_services.sh` and `script/setup_vps.sh` | ABANDONED | Immutable Compose release; never install or start legacy systemd services. |

## Generated evidence

The files under `docs/qa/` other than the explicitly listed plans are
`GENERATED` inventories or snapshots. They describe the checkout at generation
time and are not architecture, release, security, or deployment authority.

## Conflict rule

When a document conflicts with this map, stop and use the CURRENT source for
that scope. Preserve superseded files for forensic context, but do not copy
their commands into a new runbook. Update this map and the document's
first-seven-line header together whenever authority changes.
