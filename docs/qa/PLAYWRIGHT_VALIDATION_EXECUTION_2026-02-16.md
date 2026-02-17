# ClawTrol Manual Validation Execution - 2026-02-16

## Scope
Executed the manual validation requested (live app + Playwright):
- Inventory of endpoints, buttons, modals
- Route accessibility sweep
- Core UI workflow checks for Kanban + task modal controls

App under test: http://192.168.100.186:4001

## Inventory Artifacts
- docs/qa/endpoint_inventory.txt (423 lines)
- docs/qa/endpoint_inventory_web.txt (290 lines)
- docs/qa/endpoint_inventory_api_v1.txt (133 lines)
- docs/qa/button_inventory.txt (720 lines)
- docs/qa/modal_inventory.txt (481 lines)
- docs/qa/button_inventory_by_file.txt
- docs/qa/modal_inventory_by_file.txt

## Route Sweep (GET)
Data file:
- docs/qa/route-sweep-latest.csv

Result summary:
- passed: 21
- skipped (auth redirect to /session/new): 77
- failed: 1

Failed route:
- /rails/conductor/action_mailbox/inbound_emails -> HTTP 500

Notes:
- This route is under Rails conductor/internal mailbox tooling and not part of normal authenticated user flow.

## Live Playwright Validation (Executed)

### 1) Kanban move updates without manual refresh
Action:
- Open board /boards/1
- Move card using NEXT (Up Next -> In Progress)

Result:
- PASS. Column/task state updated in-session (no manual F5 required).

### 2) Task modal fields persist changes
Task used:
- #75 (/boards/1/tasks/75)

Actions + results:
- Model changed and persisted (Gemini) -> PASS
- Priority changed and activity entry logged -> PASS
- Recurring toggled and persisted -> PASS
- Nightly Task toggled and persisted -> PASS

### 3) Agent persona assignment/removal from task context
Actions:
- Assign persona from task context
- Remove assignment via the X on card pill

Result:
- PASS. Assign and unassign both worked and persisted.

### 4) Console/runtime notes
Observed:
- Repeated CSP Report-Only messages in browser console.

Result:
- Non-blocking for tested flows (informational/report-only).

## Backend Wiring Check (Functionality, not just UI)
Code references verified:
- Recurring processing job: app/jobs/process_recurring_tasks_job.rb
- Nightly gating + delays in auto-runner: app/services/agent_auto_runner_service.rb
- Nightly window config (23-08): config/application.rb
- Model/pipeline routing: app/services/pipeline/claw_router_service.rb
- OpenClaw wake/spawn webhook paths consuming model/persona: app/services/openclaw_webhook_service.rb
- Task recurring model behavior: app/models/task/recurring.rb

Conclusion:
- model, recurring, nightly, and agent/persona assignment are wired to backend execution paths.

## Final Status
- Manual validation requested: COMPLETED
- Primary user-facing flows tested: PASS
- Remaining issue to triage: Rails conductor route HTTP 500 (/rails/conductor/action_mailbox/inbound_emails)
