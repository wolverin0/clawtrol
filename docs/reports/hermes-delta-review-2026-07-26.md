# Hermes Upstream Delta Review — 2026-07-26
> Covers the ClawTrol integration delta from Hermes `16abb74e` (2026-05-18, v0.14-era) through the live `67e73ae9` and official upstream observed today.
> Baseline/head: `16abb74e` → tagged v0.19.0 plus post-tag changes; refreshed upstream was `bd6437d6` at review time.
> Verdict: preserve Hermes as an independently operated system; replace ClawTrol's direct dual-backend surface with a passive, schema-gated, metadata-first mirror.
> Key terms: `state.db`, schema v11→v22/v23, profiles, `API_SERVER_KEY`, passive mirror, TaskRun, read-only SQLite.
> Priority: MUST remove broad Hermes credentials/direct execution and harden the mirror before any revived deployment.
> Read before changing `app/services/agent_platforms/*`, profile fields/UI, `FileViewerController`, or `script/hermes_clawtrol_logger.py`.

## Executive verdict

The May integration preserved useful reconnaissance, but its product boundary is now wrong. Hermes has grown from a CLI/gateway with an internal SQLite session store into a fast-moving multi-profile platform with desktop/web clients, a full session API, per-profile gateways, remote authentication, richer session metadata, projects, cron providers, and substantially stronger security controls.

ClawTrol should **not** become another Hermes control plane. The approved target remains:

```text
Hermes runtime/state ── read-only, least-privilege mirror ──> ClawTrol tasks/runs/events
```

The current direct adapter, profile credential fields, and “Hermes Only / Dual Backend” UI imply execution/control capabilities that are unused, unstable, and contrary to that boundary. The passive logger is the right seed, but it is not safe enough to run unattended yet.

## Provenance and comparison window

| Reference | Commit | Date | Meaning |
|---|---|---:|---|
| Integration design baseline | [`16abb74e`](https://github.com/NousResearch/hermes-agent/commit/16abb74eab2d0bd34efc0e94a17846507a0c952c) | 2026-05-18 | Hermes commit used by the May 21 ClawTrol work |
| Latest release tag | [`v2026.7.20`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.7.20) | 2026-07-20 | v0.19.0; tag commit `3ef6bbd2` |
| Live server checkout | [`67e73ae9`](https://github.com/NousResearch/hermes-agent/commit/67e73ae95899c57b9b9134b4b10a2520dffd0a16) | 2026-07-20 | v0.19.0 code, 26 commits after the release tag |
| Server-observed upstream | [`d7b36070`](https://github.com/NousResearch/hermes-agent/commit/d7b36070ef807841699ad32c5b6af547fee3ff64) | 2026-07-20 | Two commits ahead of the live checkout |
| Refreshed official `main` | [`bd6437d6`](https://github.com/NousResearch/hermes-agent/commit/bd6437d60518606fffd4db035327ea4ce9d11729) | 2026-07-26 | Upstream at review time; unreleased and still moving |

At refresh time, official `main` was 9,371 commits beyond the May baseline and 1,523 commits beyond the live server checkout. That is evidence against tracking `main` blindly, not evidence that the live server should be updated immediately. Use the [baseline-to-v0.19 comparison](https://github.com/NousResearch/hermes-agent/compare/16abb74eab2d0bd34efc0e94a17846507a0c952c...v2026.7.20) for the stable window and treat [post-v0.19 `main`](https://github.com/NousResearch/hermes-agent/compare/v2026.7.20...main) as an unsoaked candidate window.

## Upstream change map

### v0.15.0 — session/control and security surface

The [v0.15.0 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.5.28) introduced the external session control API, a large session-search rewrite, Bitwarden support, stronger promptware defenses, and more mature multi-profile/kanban behavior. The important ClawTrol implication is that Hermes gained a supported session resource surface, but its bearer key is not read-only.

- `/api/sessions/*` added list/create/read/patch/delete/fork/chat operations ([PR #33134](https://github.com/NousResearch/hermes-agent/pull/33134)).
- `session_search` moved to direct FTS-backed discovery/scroll/browse ([PR #27590](https://github.com/NousResearch/hermes-agent/pull/27590)).
- Promptware defenses and managed credential sources expanded the sensitive-data boundary ([PR #32269](https://github.com/NousResearch/hermes-agent/pull/32269), [PR #30035](https://github.com/NousResearch/hermes-agent/pull/30035)).

### v0.16.0 — remote gateway and concurrent profiles

The [v0.16.0 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.6.5) made remote gateways and concurrent multi-profile sessions first-class. A Hermes “profile” is now a complete state boundary, not a cosmetic CLI flag.

- Each profile owns config, secrets, sessions, cron jobs, memory, and its own `state.db`.
- Remote desktop/gateway authentication and profile-specific remote hosts were added ([PR #37888](https://github.com/NousResearch/hermes-agent/pull/37888), [PR #39778](https://github.com/NousResearch/hermes-agent/pull/39778)).
- Session schema reached v14 and added `cwd`, `rewind_count`, and `archived`.

### v0.17.0 — multiplex gateways and pluggable cron

The [v0.17.0 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.6.19) added opt-in profile multiplexing and a pluggable cron scheduler.

- One gateway can multiplex profiles ([PR #48273](https://github.com/NousResearch/hermes-agent/pull/48273)).
- Cron gained a provider contract/Chronos path ([PR #48275](https://github.com/NousResearch/hermes-agent/pull/48275)).
- Security fixes scrubbed cron subprocess environments and strengthened command approval failure behavior ([PR #49207](https://github.com/NousResearch/hermes-agent/pull/49207), [PR #40591](https://github.com/NousResearch/hermes-agent/pull/40591)).
- Session schema reached v16.

ClawTrol must therefore identify the profile that owns each mirrored session. Reading only `~/.hermes/state.db` is incomplete when named profiles exist.

### v0.18.0 — project/workspace identity and operational hardening

The [v0.18.0 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.7.1) made projects/workspaces and verification evidence first-class and closed a large reliability/security backlog.

- Session schema v17 added `session_key`, `chat_id`, `chat_type`, `thread_id`, `git_branch`, and `git_repo_root`.
- API server concurrency limits and run-scoped approvals were added ([PR #50007](https://github.com/NousResearch/hermes-agent/pull/50007), [PR #56129](https://github.com/NousResearch/hermes-agent/pull/56129)).
- Cron credential-exfiltration and provider-drift paths were hardened ([PR #56196](https://github.com/NousResearch/hermes-agent/pull/56196), [PR #51051](https://github.com/NousResearch/hermes-agent/pull/51051)).

These columns are valuable passive metadata for ClawTrol. They should be captured when present, never assumed.

### v0.19.0 — state consolidation, routed profiles, durable delivery

The [v0.19.0 release](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.7.20) is the relevant stable target for the live server.

- Gateway session metadata and routing moved into `state.db`; `sessions.json` became an optional legacy mirror ([PR #58899](https://github.com/NousResearch/hermes-agent/pull/58899), [PR #59203](https://github.com/NousResearch/hermes-agent/pull/59203)).
- Session schema v22 added `display_name`, `origin_json`, `expiry_finalized`, `profile_name`, and compression state.
- Profile-based inbound routing and multiplex hardening landed ([PR #64835](https://github.com/NousResearch/hermes-agent/pull/64835), [PR #65700](https://github.com/NousResearch/hermes-agent/pull/65700)).
- Final responses gained a durable delivery-obligation ledger in `state.db` ([PR #67181](https://github.com/NousResearch/hermes-agent/pull/67181)).
- Sessions gained filtered export/archive/prune flows with an optional redaction pass ([PR #60186](https://github.com/NousResearch/hermes-agent/pull/60186), [PR #60492](https://github.com/NousResearch/hermes-agent/pull/60492)).
- `hermes config get`/`unset` became supported CLI operations ([PR #65540](https://github.com/NousResearch/hermes-agent/pull/65540)).
- Secret sources expanded to a pluggable Bitwarden/1Password interface ([PR #59498](https://github.com/NousResearch/hermes-agent/pull/59498)).

### Post-v0.19 unreleased head

Today’s upstream `main` is not a small patch over the server checkout. It reached session schema v23 and contains another SQLite-safety wave. These changes are directly relevant to the mirror but are not a reason to upgrade the live runtime without a separate soak.

- Hermes documented and fixed POSIX lock cancellation caused by raw file opens against live SQLite databases ([`fbd5e577`](https://github.com/NousResearch/hermes-agent/commit/fbd5e5772a45e7044820a56372c61ac0f11560bf)).
- Connection tracking was made fail-closed and path-correct ([`95fb4778`](https://github.com/NousResearch/hermes-agent/commit/95fb47785beca4b1472d8a2b9fd3817eece0e04a), [`fe431651`](https://github.com/NousResearch/hermes-agent/commit/fe431651c710d5576a63d2069f4d2da426ee2e29)).
- Snapshot check/use races and damaged metadata handling were hardened ([`9657f6e3`](https://github.com/NousResearch/hermes-agent/commit/9657f6e343dba505128fe24e21ed65a3835905bf)).
- Schema v23 adds `compression_ineffective_count` and `pinned` and changes FTS storage handling.

## Contract changes that affect ClawTrol

### CLI

The four commands used by `HermesAdapter` still exist on current upstream:

| ClawTrol call | Current status | Verdict |
|---|---|---|
| `hermes --version` | Stable | Acceptable as a host-side health probe |
| `hermes status --all` | Exists; human-oriented/redacted text | Do not parse for a durable integration contract |
| `hermes sessions list` | Exists; rich filters, human output | Do not expose raw text as a structured adapter API |
| `hermes cron list --all` | Exists; human output | Do not use as a ClawTrol control surface |

`hermes config get model --json` is now a better model-inspection command than regex-parsing `status --all`, but the passive architecture does not need Rails to invoke it on web requests. Host-side diagnostics may use it.

### Profiles, home, and workspace

Official Hermes semantics now clearly separate:

- profile: state/config/security boundary under `HERMES_HOME`;
- workspace/`terminal.cwd`: where tools start;
- project: a higher-level coding organization surface.

See the tagged [profiles guide](https://github.com/NousResearch/hermes-agent/blob/v2026.7.20/website/docs/user-guide/profiles.md). A profile does not sandbox filesystem access, and a sticky active profile can redirect bare `hermes` commands. ClawTrol’s independent `hermes_home` plus nullable `hermes_profile` fields are therefore ambiguous. A mirror should discover explicit profile roots and stamp each event with a profile identity; it should not reproduce Hermes profile selection in each ClawTrol user record.

### Session database

Hermes explicitly documents `state.db` as an internal schema that changes between releases. The stable [session storage guide](https://github.com/NousResearch/hermes-agent/blob/v2026.7.20/website/docs/developer-guide/session-storage.md) and [session user guide](https://github.com/NousResearch/hermes-agent/blob/v2026.7.20/website/docs/user-guide/sessions.md) are the primary references.

Observed schema progression:

| Reference | Schema | Additions relevant to the mirror |
|---|---:|---|
| `16abb74e` | 11 | baseline sessions/messages, costs, handoff fields |
| v0.15.0 | 13 | storage/migration hardening |
| v0.16.0 | 14 | `cwd`, `rewind_count`, `archived` |
| v0.17.0 | 16 | lifecycle/delegation migrations |
| v0.18.0 | 17 | session/chat keys, branch and repo identity |
| v0.19.0 | 22 | display/origin/expiry/profile/compression metadata |
| 2026-07-26 `main` | 23 | `pinned`, compression counter, FTS storage transition |

Core fields currently used by the logger remain present, so the logger is not proven broken on v0.19. It is nevertheless unsupported-by-contract and lacks a compatibility gate.

### API and security

Hermes now exposes authenticated session REST endpoints, but `API_SERVER_KEY` protects an API that can run the agent’s full toolset, including terminal commands. Official docs require the key even on loopback and advise a narrow CORS allowlist; see the tagged [API server guide](https://github.com/NousResearch/hermes-agent/blob/v2026.7.20/website/docs/user-guide/features/api-server.md).

Consequences:

1. Do not enable the Hermes API server only to feed ClawTrol.
2. Do not store `API_SERVER_KEY` or equivalent gateway/hook credentials in ClawTrol.
3. Reconsider the API only if Hermes ships a genuinely read-only, least-privilege session token or an explicit export/feed contract.
4. Keep the mirror pull-based and local to the host.

## ClawTrol findings

### `app/services/agent_platforms/*`

**REMOVE before revived deployment**

- `HermesAdapter` advertises a direct backend that no production caller currently uses.
- `Registry` and the `hermes_only`/`dual` modes imply task routing/execution that the approved architecture forbids.
- Sessions and cron methods return unstable human CLI output rather than a typed contract.
- Running a subprocess with a 20-second timeout from a Rails request is an avoidable availability risk.

Retain only a separate, operator-only host health probe if needed. It should not be selected as an execution backend.

### Profile model/controller/view

**REMOVE**

- `hermes_gateway_url`, `hermes_gateway_token`, and `hermes_hooks_token` are stored and rendered but are unused by the adapter.
- The password inputs place decrypted token values back into the rendered form value, expanding exposure to browser DOM, password managers, screenshots, and client-side instrumentation.
- `hermes_home`/`hermes_profile` duplicate host runtime topology inside per-user application state.

Use host-side environment/configuration for the passive mirror. Do not migrate secrets into a new table.

### `FileViewerController`

**CHANGE or REMOVE**

The default `~/.hermes/artifacts` root is not an official Hermes artifact contract on either v0.19 or current upstream. It creates a misleading empty/dead surface. If ClawTrol needs to render exported evidence:

- point `HERMES_VIEWER_DIR` to a dedicated, ClawTrol-owned export directory outside raw `HERMES_HOME`;
- keep it read-only;
- never serve `state.db`, auth stores, profile `.env`, logs, checkpoints, cron state, or arbitrary workspace files;
- consider removing the logical root until such an export producer exists.

### `script/hermes_clawtrol_logger.py`

The script’s pull direction and use of the existing ClawTrol API are good. Its current risks are:

1. **Internal schema assumption** — no `schema_version` or `PRAGMA table_info` compatibility gate.
2. **Connection lifecycle** — each fetch opens `sqlite3.connect()` without an explicit close.
3. **Read mode** — it does not use URI `mode=ro`, `PRAGMA query_only=ON`, a bounded busy timeout, or an explicit read transaction.
4. **Missed activity** — the six-hour filter uses session `started_at`; a long-running or resumed older session can receive new messages and never be seen.
5. **Incomplete platforms** — defaults to `telegram,cron,cli`, omitting desktop/web/API/Discord/Slack and future plugin sources.
6. **Profile blindness** — it reads one database and does not stamp `profile_name`.
7. **Writes under Hermes home** — the cursor map defaults to `~/.hermes/clawtrol-logger/state.json`, contradicting “read-only against Hermes”.
8. **Credential sprawl** — it searches `~/.openclaw/.env`, `~/clawdeck/.env`, and `~/.hermes/.env`; the revived architecture has one secure host-side environment source and must not revive OpenClaw coupling.
9. **P0 data-contract violation** — mirrored agent output is written into `tasks.description`; ClawTrol reserves that field for the human brief. Output belongs in `TaskRun` and runtime events.
10. **Sensitive content replication** — first user messages, latest assistant output, tool calls, and tool results may contain credentials or private data. Truncation is not redaction.
11. **No version fixture matrix** — the self-test checks helpers, not live-schema compatibility, lock contention, idempotent replay, privacy, or API failures.

The current `--self-test` passes, which proves only its small pure-helper assertions.

## Prioritized actions

### MUST — deployment blockers

1. **Remove direct Hermes control from ClawTrol.**
   - Remove/disable `hermes_only` and `dual` execution selection.
   - Remove the unused gateway URL/token/hook fields and token-valued form rendering.
   - Do not add Hermes API/gateway credentials elsewhere.

2. **Replace the logger’s database reader with a compatibility adapter.**
   - Open `file:<path>?mode=ro` with `uri=True`.
   - Set `PRAGMA query_only=ON` and a short `busy_timeout`.
   - Use `contextlib.closing`/`with` and an explicit read transaction.
   - Read `schema_version` and `PRAGMA table_info`; fail closed with a clear unsupported-schema event.
   - Never copy/open raw live database bytes. If a snapshot is required, use SQLite’s backup API.

3. **Make mirroring truly passive and profile-aware.**
   - Put cursor/idempotency state under a ClawTrol-owned host state directory.
   - Configure explicit profile-name → `state.db` mappings outside the application DB.
   - Select changed messages by message timestamp/ID, not only session start time.
   - Default to all sources or an explicit allowlist that is complete and observable.

4. **Honor ClawTrol’s P0 task contract.**
   - Keep `Task.description` a short immutable mirror brief.
   - Persist Hermes output in a `TaskRun` keyed by `hermes:<profile>:<session>`.
   - Append normalized runtime events through the existing idempotent `(run_id, seq)` path.

5. **Add privacy controls before copying content.**
   - Metadata-only by default.
   - Explicit opt-in for message excerpts.
   - Redact known secret patterns and tool arguments/results before network transfer.
   - Never log tokens, headers, raw env values, or Hermes auth/config contents.

6. **Pin and test Hermes; do not follow `main`.**
   - Keep live Hermes unchanged during ClawTrol revival.
   - Record the tested Hermes commit in mirror health.
   - Upgrade Hermes in a separate window with backup, schema-fixture tests, and rollback.

### SHOULD — next robustification slice

- Capture optional v0.19 metadata when columns exist: `profile_name`, `display_name`, `session_key`, source/chat identity, `cwd`, `git_repo_root`, `git_branch`, model/provider, cost, archived/ended state.
- Add fixture databases for schemas 11, 14, 17, 22, and 23.
- Test against a live WAL writer, locked DB, malformed DB, missing columns, duplicate delivery, ClawTrol 401/429/5xx, and interrupted cursor writes.
- Add health output: Hermes commit/version, profile, schema version, last successful cursor, lag, sessions/events mirrored, duplicates, redactions, and last error.
- Exponential backoff with jitter and a single-process lock.
- Mark `docs/qa/DUAL_BACKEND_HERMES_TEST_PLAN.md` superseded by a passive-mirror test plan; preserve it as history.
- Add an enforcement test that fails if Hermes secrets or direct execution fields/routes reappear.

### DEFER

- Hermes session REST ingestion until a least-privilege read-only credential exists.
- Remote model switching, cron CRUD, session spawn/send, gateway lifecycle control, projects/kanban federation, and cross-control-plane orchestration.
- Tracking unreleased schema v23 behavior in production; fixtures may cover it, deployment should target the pinned server commit.

### REMOVE

- `hermes_gateway_url`, `hermes_gateway_token`, `hermes_hooks_token`.
- Direct `HermesAdapter` execution selection and unused orchestration modes.
- Default raw `~/.hermes/artifacts` viewer root.
- OpenClaw `.env` fallback in the Hermes logger.
- Mirror cursor state under `~/.hermes`.
- Agent output in `Task.description`.

## Proposed implementation order

1. Add compatibility/privacy tests around the existing logger.
2. Introduce the read-only multi-profile reader and ClawTrol-owned cursor store.
3. Add a TaskRun-compatible mirror API path or adapt the existing completion hook safely.
4. Switch to metadata-only default and opt-in redacted excerpts.
5. Remove direct adapter/profile-secret surfaces and supersede the dual-backend test plan.
6. Run isolated end-to-end mirroring against copied schema 11 and schema 22 databases.
7. Only then enable the passive sidecar on the host and observe it without changing Hermes.

## Verification performed for this review

- Cloned/fetched only the official `NousResearch/hermes-agent` repository into a temporary reference directory.
- Verified baseline, live, reported-upstream, release-tag, and refreshed-head ancestry/counts.
- Inspected tagged/current official CLI parsers, release notes, session schema, API routes/auth, profile semantics, cron, and SQLite safety changes.
- Inspected all ClawTrol Hermes touchpoints named in scope.
- Ran `python script/hermes_clawtrol_logger.py --self-test` — pass.
- Made no Hermes server, deployment, runtime, database, credential, or ClawTrol application-code changes.
