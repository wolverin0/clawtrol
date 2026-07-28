# Control Room Fleet Ask — Live Release Evidence
<!-- Covers the fleet-wide Ask Orchestrator handoff, pane-0 wake-up, follow-up Send path, and exact-SHA release proof. -->
<!-- Key terms: T-0017, intent 8, intent 9, _fleet, pane 0, authenticated Chrome, exactly-once notification. -->
<!-- Read this to verify that the cockpit now produces real orchestrator work and visible answers rather than passive cards. -->
<!-- Rails revision: 497c75084f3532b9f3c0f43ad69cfdda9585c38d. Wezbridge revision: 05f05cbdd3c1184d41c7ab56d3fe95e281623b20. -->
<!-- Image digest: sha256:f6d60714b7b626c1c65df92425f67804928bbe499c9f2d46b350461a990a3bf5. -->
<!-- Updated: 2026-07-28 after the authenticated fleet question and follow-up round trip. -->

## Outcome

`Ask Orchestrator` now defaults to the whole fleet. Submitting a question
creates an `_fleet` ledger task, durably binds the operator question to that
task, and wakes pane 0 exactly once. Pane 0's answer is mirrored back into the
same Control Room thread.

The user then sent a follow-up from the thread. The message appeared
immediately as `You`, became a bridge intent, woke pane 0, and received a
second answer in the same thread. The reply capability remains the tracked
`claw-8qt` manual audited append on the pane-0 side; no hidden direct pane
control was added to Rails.

## Authenticated Chrome proof

- Intent `#8` created ledger task `T-0017` from the default
  `All open panes — fleet assessment` context.
- The bridge applied the request in about 23 seconds and pane 0 began working
  without terminal discovery or a manual A2A prompt.
- Pane 0 returned an 18-pane fleet assessment covering project-health,
  graph-contract coverage, blocked operator decisions, idle panes, and an
  unwatched cross-project database blast radius.
- The thread's `Send` action accepted the exact operator follow-up as intent
  `#9`, rendered it immediately as `You`, and showed `Applied`.
- Pane 0 returned an ordered three-phase recommendation: graph contracts,
  sensor corrections, then first-class cockpit replies.
- Chrome reported no page-console errors during the flow.

## Verification and release

| Gate | Evidence |
|---|---|
| Wezbridge focused tests | 21 passed, 0 failed. |
| Wezbridge full suite | 331 passed, 0 failed, 1 pre-existing skip. |
| Hosted Rails CI | Lint, Rails tests, real-browser system tests, security, migration, mirror, passive-Hermes boundary, JavaScript audit, and image build passed for the exact merged SHA. |
| Isolated restored database | Exact image migrated a fresh active-database dump with no pending migrations; counts were 5 users, 7 boards, 449 tasks, and 211 TaskRuns. |
| Runtime health | `/health` returned `status: ok` and exact revision `497c75084f3532b9f3c0f43ad69cfdda9585c38d`; `/up` returned success. |
| Runtime topology | One Compose web service, one Puma process, zero workers, and all three retired systemd units inactive. |

The isolated restore container and network were removed after verification.
The fresh pre-release dump remains at the private VM deployment backup
location for rollback.

## Operator model

The browser is where the operator starts work and reads answers. ClawTrol
stores the disposable projection and signed operator intents. The PC bridge
polls those intents outbound, writes the durable ledger, and notifies pane 0.
Pane 0 reasons over the live fleet and writes its answer to the task message
ledger. The bridge mirrors that answer back to ClawTrol.

ClawTrol still does not execute arbitrary pane commands, own credentials for
the panes, or become the ledger authority.
