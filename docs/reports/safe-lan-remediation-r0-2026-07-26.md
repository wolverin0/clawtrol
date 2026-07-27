# Safe-LAN Remediation R0 Evidence — 2026-07-26
<!-- Covers governance setup, recovery anchors, live topology, active database backup, and stopped-worker proof. -->
<!-- Key terms: 9035ed8, 5/7/433/195, active-app database, container-only runtime, degraded health. -->
<!-- Read when starting R1, restoring data, or checking whether the recovery baseline was preserved. -->
<!-- Scope: read-only runtime inspection plus a new access-restricted backup; no deploy, migration, or worker start. -->
<!-- Verdict: R0 anchors captured; runtime encryption health is degraded and tracked for R3. -->
<!-- Status: CURRENT evidence for remediation/safe-lan-revival-20260726. -->

## Repository and governance

- Recovery anchor: `9035ed84d1a2f9fd40469ce59815054a61888324`.
- Dedicated worktree branch: `remediation/safe-lan-revival-20260726`.
- Beads restored with `bd 1.1.2` and Dolt `2.2.2`.
- Tracking graph: 54 beads total, including all 36 audit findings, five shared root causes, ordered R0-R4/final-verification dependencies, and a deferred review on 2026-08-31.
- Decision register: `remediation-decisions.md`; no finding is accepted.

## Fresh active-database anchor

The app does not use its Compose-adjacent `clawdeck-db-1` database. The running web container targets the host database service at `host.docker.internal:5432`, database `clawdeck_development`. No database password or raw connection URL was captured.

The active database dump is stored outside the repository:

`$HOME/backups/clawtrol/20260727T022542Z-safe-lan-r0/active-app-database.dump`

| Evidence | Value |
|---|---|
| Dump bytes | 3,832,507 |
| SHA-256 | `b516299bae0ce3e87bb92563af7d463afed3c9457fbf69c27d1ef5c79e21d11c` |
| `pg_restore --list` entries | 782 |
| Users | 5 |
| Boards | 7 |
| Tasks | 433 |
| Task runs | 195 |

The backup directory is mode-restricted and also contains allowlisted container metadata, configuration names only, health output, process evidence, counts, hashes, and the restore list. Raw `docker inspect` output and environment values were not saved.

## Runtime topology and health

- Running containers: `clawdeck-clawdeck-1` and `clawdeck-db-1`, both reported Docker health `healthy`.
- Web image identity: `sha256:c42a0b167f1cff83a9258ca69e4677c484c24c5810e866c0006802734bf3d540`.
- Compose database image identity: `sha256:108b27c919e6e7bc124350fb265deea9adac58e118eade428c6d1ad44b90debe`.
- The Compose labels still name `$HOME/clawdeck/docker-compose.yml`, but that working directory no longer exists. Deployment documentation must not assume a pullable VM checkout.
- `/up` returned `200`.
- `/health` returned `503` because Active Record encryption lacks its primary-key runtime configuration. Database, Solid Queue, and cache checks were healthy.
- The web container process inventory contained one Puma process and no Solid Queue worker.
- `clawdeck-web.service`, `clawtrol.service`, and `clawtrol-worker.service` were all inactive.

The adjacent `clawdeck-db-1` database contains only `1 user / 1 board / 7 tasks / 0 task runs`; it is not the active application database and must not be used as the revival restore source.

## R0 boundary

No application source, live data row, container, image, systemd unit, worker, route, or scheduled job was changed. R1 may start from these anchors. The missing encryption configuration and stale deployment topology are explicit R3 work; they are not hidden by the Docker-health result.
