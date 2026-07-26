# ClawTrol Revival Baseline Evidence — 2026-07-26
> Covers: production-safe database backup, live-container source recovery, PC baseline, and independent verification.
> Key terms: `bbb7551`, `recovery/live-container-20260726`, passive Hermes mirror, isolated restore.
> Read when: continuing the revival, reviewing the recovered delta, or preparing a replacement deployment.
> Baseline SHA: `bbb75510de0d3ebd9c3efbfea7040c010c46c938`.
> Verdict: recovered and reproducible; not approved for deployment because dependency and static-analysis gates remain open.
> Production impact: none; the live container stayed healthy and legacy worker processes stayed off.

## Recovery result

- Captured a custom-format PostgreSQL dump before source recovery.
- Captured allowlisted runtime metadata rather than raw `docker inspect` output, which can contain environment secrets.
- Copied `/app` from the live container to an untouched host recovery directory.
- Recorded 10,651 recovered files and per-file SHA-256 hashes.
- Copied the recovered tree to the canonical PC workspace.
- Verified the host and PC trees with the same normalized whole-tree content hash: `9fd7b9d3c44042b8292afcc5e619b3b720a3353e4ab5c7db0e65af39399af56f`.
- Attached the recovered delta to the existing `origin/main` history instead of creating an unrelated history.

The host backup is under `$HOME/backups/clawtrol/2026-07-26-190629`. The raw recovered source remains under `$HOME/projects/clawtrol-revival`. Both are outside the production container.

## Data and rollback evidence

The dump is 3,832,248 bytes with SHA-256:

`a8382229ed547d3aba44c15fb4034f05e863575e3a7ae03fc1886dc424b7c29a`

`pg_restore --list` returned 782 entries. A real restore into an isolated local PostgreSQL database completed successfully and returned:

| Entity | Live before backup | Isolated restore |
|---|---:|---:|
| Users | 5 | 5 |
| Boards | 7 | 7 |
| Tasks | 433 | 433 |
| Task runs | 195 | 195 |

The restored database size was 36 MB. No restore command targeted the live database.

## Source reality

The live container was not identical to GitHub `origin/main`. The recovery commit preserves 24 changed or added files, including a May 2026 direct Hermes dual-backend implementation:

- encrypted Hermes gateway and hook fields on users;
- backend adapters and a Hermes CLI runner;
- profile controls for OpenClaw/Hermes modes;
- batch runtime event logging;
- a read-only Hermes artifact viewer root.

This code is historical evidence, not the approved target architecture. The revival target remains a passive Hermes-to-ClawTrol task mirror with no Hermes tool proxy, no autonomous executor, and no broad Hermes credential stored in ClawTrol.

## Verification evidence

| Gate | Result | Evidence |
|---|---|---|
| Recovered-tree transfer | Pass | Host and PC normalized content hashes match |
| Staged secret scan | Pass | Gitleaks: 0 findings in the recovery commit |
| Docker build | Pass | Isolated image `clawtrol-revival:bbb7551-test` built successfully |
| Recovered-area tests | Pass | 75 runs, 175 assertions, 0 failures, 0 errors |
| Full tests, clean serialized DB | Pass | 2,567 runs, 5,656 assertions, 0 failures, 0 errors, 71 skips |
| RuboCop | Pass | 864 files, 0 offenses |
| Brakeman | Partial | 0 security warnings; exit 7 from one existing ERB parser error |
| Dependency audit | Fail | Current advisory DB reports vulnerable locked dependencies |
| Parallel test stability | Partial | One shared-file `AgentRegistry` error; the isolated test passed five consecutive seeds |
| Isolated database restore | Pass | Dump restored and historical counts matched |

The dependency audit identified advisories affecting 14 locked dependency names, including high-severity advisories for `addressable`, `faraday`, `jwt`, `oauth2`, `puma`, and `websocket-driver`. Exploitability in this application has not yet been triaged.

## Remaining release gates

- Update and regression-test vulnerable dependencies.
- Resolve or formally triage the Brakeman ERB parser error.
- Isolate the ZeroBitch agent-registry test file per parallel worker.
- Remove or disable direct Hermes/OpenClaw execution paths before any revived deployment.
- Implement and test the narrow passive mirror against board 5.
- Keep the current production container and image as rollback anchors until replacement acceptance.

No production migration, worker start, task dispatch, container replacement, or deployment occurred in this recovery phase.
