# Safe-LAN Remediation R1-R4 Evidence — 2026-07-27
<!-- Covers repository containment, immutable release controls, passive Hermes mirror, and remaining incident gates. -->
<!-- Key terms: R1, R2, R3, R4, inert HTML, immutable image, passive mirror, credential fingerprint. -->
<!-- Read before approving history rewrite, credential cutover, deployment, or the Hermes canary. -->
<!-- Scope: remediation branch and read-only runtime audit; production was not migrated, scrubbed, or deployed. -->
<!-- Verdict: implementation candidate exists, but release remains blocked by rotation, purge, restore, and soak gates. -->
<!-- Status: CURRENT execution evidence for remediation/safe-lan-revival-20260726. -->

## Candidate scope

- Recovery base: `9035ed84d1a2f9fd40469ce59815054a61888324`.
- Working branch: `remediation/safe-lan-revival-20260726`.
- Runtime remains on its pre-remediation image. No push, force update, migration, cutover, sidecar start, or deployment occurred.
- Existing recovery dump remains untouched at the access-restricted host backup recorded by the R0 report.

## R1 credential incident

Evidence uses SHA-256 fingerprint prefix `dbdd9ead9e6d9ef8`; the credential value was never printed or written to this repository.

| Corpus | Confirmed occurrence count |
|---|---:|
| Live container environment metadata | 1 |
| Live container logs | 0 |
| Live container application/config/log/storage/tmp archive | 2 |
| Active database rows | 19 |
| Restored SQL stream from the pre-remediation dump | 39 |
| Host clone configuration files | 0 |
| Remediation working tree | 0 |
| Complete Git history | 2 findings |

Database matches are limited to:

- `agent_activity_events.message`: 7 rows
- `agent_activity_events.payload`: 7 rows
- `task_runs.agent_activity_md`: 3 rows
- `tasks.description`: 2 rows

The two historical findings are in the former Nightshift/agent-runner credential header paths. The live container token still matches the exposed fingerprint. Rotation must therefore precede live data scrubbing, followed by the coordinated all-ref history rewrite and collaborator re-clone.

No secure host-side runtime environment file existed at the expected locations. Cutover requires staging a mode-restricted runtime environment and recreating the web container from the tested immutable image. This remains an operator maintenance-window gate.

## R2 containment

- Legacy executor routes/actions/jobs fail closed with `410 Gone`; normal health and scoped bearer API paths remain available.
- OpenClaw, Factory, Nightshift, ZeroBitch, image generation, fake session health, and placeholder debate execution are disabled.
- Marketing HTML was moved out of `public/`; Marketing, Preview, Showcase, and file-viewer HTML is returned as inert source/attachment with `text/plain`, `nosniff`, no-store, and sandbox CSP.
- Direct webchat controls, iframe behavior, direct Hermes adapters/CLI control, credential-valued forms, and raw Hermes artifact roots were removed.
- Compose has no embedded database credential or worker and requires host-supplied production secrets.

## R3 release controls

- Release images require an exact 40-character Git SHA and expose `APP_REVISION` through `/health`.
- Production entrypoint and Compose fail closed when required runtime database, application, and Active Record encryption values are missing.
- Deployment consumes a prebuilt SHA-tagged image; it does not pull source, build on the VM, or run boot-time migrations.
- CI gates RuboCop, Rails tests, Brakeman, Bundler Audit, importmap audit, complete-history Gitleaks, migration policy/rebuild, mirror tests, and the passive-Hermes boundary.
- The expand/contract checker inspects forward migration methods only, so rollback code cannot create a false positive.
- `docs/DOCS-MAP.md` marks current topology/evidence and superseded pull-restart/systemd guidance.

## R4 passive Hermes mirror

- API tokens retain expiry and add scopes/revocation (`401` expired/revoked; `403` missing scope).
- Dedicated idempotent session, event, and completion endpoints require `hermes_mirror:write`.
- Tasks use user-scoped `hermes:<profile>:<session_id>` origin keys; TaskRuns retain internal `run_id` plus unique external source keys.
- The sidecar maps profiles explicitly, rejects `ALL`, opens SQLite read-only/query-only, fails unsupported schemas closed, advances timestamp/ID cursors atomically, and defaults to metadata-only.
- Schema fixtures cover versions 11, 14, 17, 22, and 23. Production still requires a freshly verified pinned live schema/commit before non-dry-run use.

## Verification ledger

| Gate | Result |
|---|---|
| Targeted containment/API/model regressions | PASS — 53 runs, 133 assertions |
| Webchat plus containment regression after direct-control removal | PASS — 9 runs, 46 assertions |
| Sidecar schema/read-only/redaction/idempotency tests | PASS — 7 tests |
| RuboCop | PASS — 868 files, 0 offenses |
| Brakeman | PASS — 0 warnings, 0 parser errors |
| Bundler Audit after targeted lockfile updates | PASS — 0 vulnerable gems |
| Importmap audit | PASS — 0 vulnerable packages |
| Passive Hermes boundary | PASS |
| Updated builder image/assets | PASS |
| Migration-chain rebuild on isolated PostgreSQL 17 | PASS |
| Remediation working-tree Gitleaks | PASS — 0 findings |
| Final complete Rails suite | PASS — 2,550 runs, 5,722 assertions, 0 failures/errors, 69 skips |
| Chromium system suite | PASS — 36 runs, 126 assertions, 0 failures/errors/skips |
| Complete-history Gitleaks | BLOCKED — 2 historical findings require coordinated rewrite |
| Restored-production-dump migration rehearsal | PENDING |
| Credential rejection, live scrub, and immutable containment deployment | PENDING maintenance window |
| 24-hour dry run, one-session canary, second 24-hour soak, seven-day column soak | PENDING |
| Fresh battle-test release verdict | NOT YET — report at `artifacts/2026-07-27-battle-test.html`; operator gates remain |

## Do-not-cross gates

Do not push this branch into shared history, deploy it, mutate the active database, rotate/revoke runtime credentials, or rewrite remote refs as an incidental development action. Those operations must be one coordinated maintenance window with expected ref SHAs, tested image/revision evidence, rollback image, runtime-environment backup, and collaborator re-clone instructions.
