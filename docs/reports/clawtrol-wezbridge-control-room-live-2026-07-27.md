# ClawTrol + Wezbridge Control Room — Live Canary Evidence
<!-- Covers the implemented personal cockpit, outbound bridge, credential boundary, exact-SHA deployment, and live canary proof. -->
<!-- Key terms: Control Room, disposable projection, single ledger writer, whatsappbot-final canary, typed intents, watchdog. -->
<!-- Read this after the control-plane plan to see what is live, what was proved, and what remains time-gated. -->
<!-- ClawTrol never receives pane-control credentials; the PC daemon initiates every connection and keeps ledger authority. -->
<!-- Production code revision: 455f4a57020b0d800fa8e7c54826ff0caf953ca8. Wezbridge revision: 8534c92df76d3aaa86ad9da0bfbd902aa8c19e32. -->
<!-- Updated: 2026-07-27. -->

## Outcome

The personal Control Room is live on the private LAN. ClawTrol is the cockpit
and disposable projection; Wezbridge remains the single local ledger writer
and the only component with pane authority. The first live scope is
`whatsappbot-final`: fleet pane metadata is visible, but task, event, and
message bodies from other projects are filtered before upload.

## Implemented boundary

- Wezbridge pushes health, pane metadata, and allowlisted task metadata to
  `POST /api/v1/orchestration/sync`; the PC exposes no inbound port.
- The bridge token has only `orchestration_bridge:sync`, expires after 90 days,
  and is loaded from an owner-only file. Its value was never printed or stored
  in repository evidence.
- ClawTrol queues typed operator intents. The bridge accepts only
  `create_task`, `message`, `approve`, `retry`, and `cancel`; ledger FSM and
  repository contracts decide whether a transition is legal.
- Task projections use `wezbridge:<profile>:task:<ledger-id>`, board 5, and
  immutable briefs. Runs, events, and replies carry the changing evidence.
- Unset project configuration fails closed: no task-scoped data uploads.
  Task-less messages are always dropped.
- Pane 0 is replaceable; the local daemon owns a 90-second absence watchdog,
  10-minute cooldown, and three-strike disable.
- The canary deploy runner is deny-by-default, SHA-pinned, migration-aware, and
  rollback-capable. It cannot deploy any repository except the explicitly
  guarded WhatsApp canary.

## Verification

| Gate | Evidence |
|---|---|
| ClawTrol hosted CI | Main run `30316021649` passed tests, system browser tests, lint, security, migration, mirror, passive-Hermes boundary, JS scan, and image build. |
| Focused pane-snapshot regression | 5 controller tests / 36 assertions; RuboCop inspected both touched files with no offenses. |
| Wezbridge | Main `8534c92`; full suite 327 pass / 0 fail / 1 pre-existing skip. Independent focused bridge/watchdog/deploy run: 32 / 32 pass. |
| Restored database | Exact image `455f4a5…` migrated and reported no pending migrations against the isolated restored production copy. |
| Immutable release | Image digest `sha256:f10ca2957fac3385e2f466d2fae41977fb20668b55630fdace9f78a859706c12`; `/up` 200 and `/health` reported `ok` with the exact revision. |
| Live browser | Real login rendered Control Room, healthy source, 16 panes, nine canary tasks, task detail/history, and sign-out. Temporary login data was restored and removed. |
| Canary scope | Nine unique projected tasks and nine unique TaskRuns, only `whatsappbot-final`, only board 5, zero `ALL` cards, stable across repeated snapshots. |
| Pane persistence | 16 panes survived multiple 5-second deltas after the live defect fix; source remained healthy with no last error. |
| Typed-intent downlink | A live `cancel` for deliberately nonexistent ledger task `T-999999` crossed ClawTrol → PC, was rejected by the kernel, persisted, returned, and left zero pending intents without changing real work. |
| Runtime topology | Compose exposes only `clawdeck`; one Puma process, zero Solid Queue workers; all three retired systemd units remain inactive. |
| Database counts | 5 users, 7 boards, 442 tasks, 204 TaskRuns. The expected `+9/+9` over the preserved 433/195 anchor is exactly the canary projection. |

The pre-cutover dump remains
`/home/ggorbalan/.local/share/clawtrol-backups/20260727T232026Z-pre-control-room.dump`
with SHA-256
`d0755f23010a352680769a905120a345c74ff3c87de671fc72299fc8452e567c`.

## Remaining gates

- Keep the WhatsApp projection as the canary through the observation window
  before widening `CLAWTROL_PROJECTS` to the fleet.
- The real watchdog absence/recovery test requires separate runtime evidence;
  focused automated tests and the live typed-intent downlink pass. The watchdog
  test must use an externally graded sacrificial orchestrator-profile pane with
  the operator present, not terminate the live oversight session.
- Do not activate the WhatsApp auto-deploy recipe while its repository is
  incident-active or dirty. Activation still requires the exact recipe values
  and an explicit operator `yes` for that repository.
- The passive Hermes mirror remains one-way and metadata-only; no direct Hermes
  control, OpenClaw, Factory, Nightshift, ZeroBitch, or legacy worker was
  restored.

The current verdict is **ready as a private-LAN canary**, not a public launch
and not a completed soak.
