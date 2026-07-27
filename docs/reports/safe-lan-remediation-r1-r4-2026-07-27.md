# Safe-LAN Remediation R1-R4 Evidence — 2026-07-27
<!-- Covers the completed credential cutover, immutable deployment, live containment proof, and passive Hermes boundary. -->
<!-- Key terms: R1, R2, R3, R4, e99beea, credential rotation, hidden pull-request refs, passive mirror. -->
<!-- Read before release approval, rollback, or the optional Hermes mirror canary. -->
<!-- Scope: tested repository state plus the production cutover; no Hermes sidecar or legacy executor was started. -->
<!-- Verdict: live Safe-LAN containment and R1-R3 are green; only the optional R4 mirror rollout and final report remain. -->
<!-- Status: CURRENT execution evidence for main and deployed revision e99beea61dbc7545adfc392dcd0bdaa2560d2513. -->

## Release identity and live topology

- Deployed revision: `e99beea61dbc7545adfc392dcd0bdaa2560d2513`.
- Image: `ghcr.io/wolverin0/clawtrol:e99beea61dbc7545adfc392dcd0bdaa2560d2513`.
- Image digest: `sha256:dd18ed2adabc72c6f5bf4973da988ee5f7013cc36547676fee79915453489106`.
- Hosted CI run `30265728361` passed security, JavaScript audit, lint, Rails tests, migration, passive-Hermes boundary, mirror, system-test, and image jobs for the deployed SHA.
- Production has one ClawTrol web container and one Puma process. No Solid Queue, Factory, Nightshift, OpenClaw, ZeroBitch, Paperclip, or legacy worker process is running.
- Retired systemd web/worker units remain inactive.

## R1 credential incident and cutover

The exposed hook credential was revoked. Evidence uses only its SHA-256
fingerprint prefix `dbdd9ead9e6d9ef8`; the value is not stored in this
repository or report.

- The shared PostgreSQL role received a new random credential. ClawTrol,
  personaldashboard, the atlas bridge, and the PostgreSQL container were
  recreated atomically with that value.
- `SECRET_KEY_BASE` and all three Active Record encryption secrets were
  replaced and stored only in the host-side mode-`0600` runtime environment.
- Six legacy API tokens were revoked. One expiring token remains active, scoped
  only to `hermes_mirror:write`, in a separate mode-`0600` sidecar environment.
- Direct-control credential columns for OpenClaw and Hermes were nulled.
- The retired hook route returns `410 Gone`, so the old value cannot authorize
  execution.
- Live database, container storage, and host runtime/config scans contain zero
  revoked-value occurrences.
- Eight stopped legacy systemd backup files containing the value were removed.
- Three database dumps containing the value were irreversibly removed.

The replacement post-rotation dump is access-restricted and restorable:

| Evidence | Value |
|---|---:|
| Backup identifier | `20260727T125506Z-post-credential-rotation` |
| Dump bytes | 3,828,791 |
| SHA-256 | `6baa29f960b6a786ec0c7afc5d7f0e6b58c3d791c9302c838b4d7dffdece51d6` |
| Restore-list entries | 785 |
| File mode | `0600` |

All writable GitHub branches and tags were rewritten with expected old ref
SHAs. GitHub-managed `refs/pull/*` retain two copies of the revoked value, but
they cannot authenticate to any live route or service. On 2026-07-27 the
operator explicitly declined GitHub Support cleanup; bead `claw-glf.2.2` and R1
were closed as contained for the private-LAN threat model.

## R2 containment

- Legacy executor routes/actions/jobs fail closed with `410 Gone`; ordinary
  health and scoped bearer API paths remain available.
- OpenClaw, Factory, Nightshift, ZeroBitch, image generation, fake session
  health, placeholder debate execution, and direct Hermes execution are
  disabled.
- Marketing HTML is outside `public/`. Marketing, Preview, Showcase, and file
  viewer HTML is returned as inert source/attachment with `text/plain`,
  `nosniff`, no-store, and sandbox CSP.
- HTML iframe/raw-preview controls were removed and malicious fixture tests
  prove scripts cannot access cookies, parent DOM, CSRF values, or authenticated
  APIs.
- Compose contains no embedded database credential or worker.

## R3 release controls and production proof

- Release images require an exact Git SHA and expose `APP_REVISION` through
  `/health`.
- Production entrypoint and Compose fail closed when runtime database,
  application, or encryption values are missing.
- Deployment consumes the tested SHA-tagged image; it does not pull source,
  build on the VM, or run boot-time migrations.
- The production dump migration rehearsal passed before cutover and preserved
  the verified counts: 5 users, 7 boards, 433 tasks, and 195 task runs.
- Live `/up` and `/health` return `200`; health reports `ok` and the exact
  deployed revision. The two other shared-role consumers also retain their
  expected health behavior.
- A Chromium production smoke passed real password authentication, board 5,
  and a task History surface. The original password digest and five-user count
  were restored immediately afterward; temporary browser credentials and
  artifacts were removed.

## R4 passive Hermes mirror

- API tokens retain expiry and add scopes/revocation (`401` expired/revoked;
  `403` missing scope).
- Dedicated idempotent session, event, and completion endpoints require
  `hermes_mirror:write`.
- Tasks use user-scoped `hermes:<profile>:<session_id>` origin keys; TaskRuns
  retain internal `run_id` plus unique external source keys.
- The sidecar maps profiles explicitly, rejects `ALL`, opens SQLite
  read-only/query-only, fails unsupported schemas closed, advances timestamp/ID
  cursors atomically, and defaults to metadata-only.
- Schema fixtures cover versions 11, 14, 17, 22, and 23.
- The sidecar has not been started. The required 24-hour dry run, one-session
  metadata-only canary, second 24-hour soak, and seven-day column-removal soak
  remain open.

## Verification ledger

| Gate | Result |
|---|---|
| Targeted containment, API, model, mirror, and schema regressions | PASS |
| RuboCop, Brakeman, Bundler Audit, and importmap audit | PASS |
| Complete Rails and Chromium system suites | PASS |
| Hosted CI for exact deployed SHA | PASS — run `30265728361` |
| Restored-production-dump migration | PASS — counts preserved |
| Immutable production health/revision | PASS |
| Authenticated login, board 5, task History | PASS |
| Live revoked-value scan | PASS — zero occurrences |
| Writable branch/tag history rewrite | PASS |
| GitHub hidden pull-ref cleanup | NOT PURSUED — operator decision; retained value is revoked and non-operational |
| Passive Hermes dry run/canary/soak | PENDING |
| Fresh battle-test release verdict | PENDING — rerun after R4, or immediately if the mirror is explicitly dropped |

## Rollback boundary

Rollback may stop the sidecar, revoke its token, and return the web container to
the previous immutable image only if schema/data integrity requires it. Never
restore a deleted secret-bearing dump, roll back the credential rotation, or
re-enable legacy execution.
