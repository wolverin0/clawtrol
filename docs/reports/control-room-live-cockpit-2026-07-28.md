# Control Room Live Cockpit — Release and Human-Use Evidence
<!-- Covers the full-width live cockpit, multi-project projection, typed intents, conversation round trip, immutable deployment, and rollback evidence. -->
<!-- Key terms: Control Room, live polling, five-project allowlist, T-0015, intent latency, disposable projection, first-class reply gap. -->
<!-- Read this to verify the 2026-07-28 private-LAN release and understand the one remaining conversation-tool limitation. -->
<!-- Rails revision: bd5c662ab40bf4f4a60323b7a27c55282fe77bae. Wezbridge revision: 1aa9036. -->
<!-- Image digest: sha256:f550b21e8bc1caac18692f51b8f31394e76eff1e09cb76d8a5a4418a2661b868. -->
<!-- Updated: 2026-07-28 after authenticated Chrome verification. -->

## Outcome

The Control Room is now a usable private-LAN cockpit rather than a static
mock-up. Its fleet, request history, task board, and selected conversation
refresh without a page reload. Forms keep draft values across refreshes.
Project and pane selectors are populated from live pane data, and the main
content uses the available desktop width.

ClawTrol remains a disposable projection. Wezbridge on the PC remains the
single ledger writer and the only component with pane authority. The VM holds
no pane-control credential and accepts only the established typed-intent
contract.

## Changes proved live

- The Control Room polls an authenticated `/control-room/live` endpoint every
  five seconds and updates only its dynamic regions.
- Recent requests remain visible after consumption and show `pending`,
  `applied`, or `rejected` outcomes with safe result summaries.
- The outbound mirror allowlist now covers every repository recognized by the
  active ledger: `whatsappbot-final`, `mutual`, `_fleet`, `wezbridge`, and
  `sandbox`.
- The first full snapshot after widening contained 14 projected tasks:
  WhatsApp 9, sandbox 2, wezbridge 1, `_fleet` 1, and mutual 1.
- A successfully applied intent now schedules one serialized 250 ms follow-up
  full snapshot. Durable result persistence still occurs before acknowledgement,
  the existing in-flight guard remains, and failure backoff is unchanged.

## Authenticated Chrome evidence

The release was exercised in the operator's logged-in Chrome session as a
human would use it:

1. The rendered main region measured 1,873 px in a 1,920 px viewport, leaving
   only the normal 16 px page margins.
2. Pane and project selectors contained the live fleet choices.
3. A task-form draft survived a live polling cycle and was then cleared.
4. The operator selected `pane 37 — mutual`, submitted the safe question
   `ClawTrol live cockpit proof`, and received task `T-0015` in the Mutual
   section without reloading.
5. The orchestrator reply `Cockpit reply received.` appeared in the selected
   conversation without reloading.
6. The operator sent a reply from that conversation. Intent `#7` was applied
   in 3.651 seconds after the immediate-follow-up fix.
7. The acknowledgement appeared in the same thread without reloading:
   `Acknowledged — reply path live. Round trip verified end to end`.

The final browser state showed both live indicators green and the verified
T-0015 conversation open.

## Verification gates

| Gate | Evidence |
|---|---|
| Rails controller tests | 7 runs, 43 assertions, 0 failures, 0 errors. |
| Focused static checks | RuboCop clean for the touched Ruby files; JavaScript syntax check clean. |
| Hosted Rails CI | 2,566 runs, 5,821 assertions, 0 failures, 0 errors, 69 skips. |
| Hosted system browser CI | 39 runs, 139 assertions, 0 failures. |
| Hosted security and delivery gates | Lint, Brakeman, Bundler Audit, full-history secret scan, migrations, mirror tests, passive-Hermes enforcement, JavaScript audit, and immutable image build passed. |
| Wezbridge | Main `1aa9036`; 330 pass, 0 fail, 1 pre-existing skip. |
| Isolated restored database | Counts matched 5 users, 7 boards, 447 tasks, and 209 TaskRuns; migration and pending-migration checks passed against the exact candidate image. |
| Immutable release | `/health` reports `ok` and exact revision `bd5c662…`; `/up` returns 200. |
| Runtime topology | One Compose web container and one Puma process; no worker process was introduced. |

The isolated verification database and temporary test container were removed
after the gate. The fresh pre-release production dump remains at
`/home/ggorbalan/.local/share/clawtrol-deploy/backups/clawdeck_development-pre-bd5c662-20260728.dump`;
its archive listing was verified before release.

## Honest remaining gap

The conversation transport works, but orchestrator replies are not yet a
first-class Claude Code action. The registered `clawtrol_task_reply` capability
is absent from Claude Code's tool surface, so the verified replies were written
through the bridge's manual, audited `task-messages.jsonl` append path. Bead
`claw-8qt`, discovered from `claw-8d9`, tracks exposing the supported tool.

This does not block viewing work, creating tasks, sending operator messages, or
receiving replies. It does mean the orchestrator-side reply step still needs
the manual bridge path and must not be described as fully automated.

## Rollback

Stop the Wezbridge bridge or remove the project allowlist to darken the
projection without affecting the PC ledger. Revoke the scoped bridge token if
transport must be disabled. Roll the web container back to its previous
immutable image pointer if the Rails release regresses. Restore the retained
database dump only if schema or data integrity requires it. Never restore
legacy executors or roll back credential rotation.
