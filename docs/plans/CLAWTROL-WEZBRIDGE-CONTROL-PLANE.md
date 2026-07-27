# ClawTrol + Wezbridge Personal Control Room
<!-- CURRENT: implementation contract for the personal-LAN orchestration cockpit. -->
<!-- Covers: Control Room UX, outbound sync, task intents, pane supervision, deployment evidence. -->
<!-- Key terms: disposable projection, single ledger writer, operator intent, exact tested SHA. -->
<!-- Read when changing ClawTrol orchestration UI/API or the Wezbridge bridge/kernel. -->
<!-- `_intel` remains authoritative; ClawTrol never owns pane or executor credentials. -->
<!-- Updated: 2026-07-27. -->

## Operating model

ClawTrol is the operator-facing cockpit and a disposable projection of Wezbridge
state. The Wezbridge daemon on the Windows PC is the single ledger writer and
retains all pane, terminal, and local credential authority. The PC initiates
every network request; ClawTrol never opens an inbound connection to it.

The operator creates tasks, asks questions, replies to workers, and handles
blocked work from `/control-room`. Pane 0 remains the replaceable reasoning
client but normally speaks through task-scoped messages in ClawTrol.

## V1 contract

- One scoped endpoint: `POST /api/v1/orchestration/sync`.
- One bridge scope: `orchestration_bridge:sync`.
- One task key: `wezbridge:<profile>:task:<ledger-id>`.
- Five operator intents: `create_task`, `message`, `approve`, `retry`, `cancel`.
- Two new records: orchestration sources and orchestration intents.
- Existing Task, TaskRun, AgentActivityEvent, AgentMessage, and TaskDependency
  records remain the projection primitives.
- Source events use rotation-safe file identities and byte cursors. Event
  application remains idempotent through each run's stable positive sequence.
- Task creation always passes through Wezbridge `contractFor()` rules. Gated
  work is born blocked and cannot be pre-approved by ClawTrol.

## Delivery and safety

Completed code work runs its project gates, commits, pushes the current branch,
deploys the exact tested revision, and verifies the live route. Failed live
smokes restore the previous deployment. Destructive data changes, credential
rotation, purchases, external messages, and scope expansion remain operator
gates.

No Rails agent, inbound PC port, arbitrary pane command, direct Hermes control,
OpenClaw, Factory, Nightshift, ZeroBitch, Paperclip, or legacy worker is part of
this design.

## Acceptance

The first canary is `whatsappbot`. It must prove mirror fidelity and rebuild,
stale detection, task conversation, pane-0 recovery in under two minutes,
exactly-once intent replay, exact-revision deployment, and live smoke evidence
before non-archived fleet projects are enabled.
