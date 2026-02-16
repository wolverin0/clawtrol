# ClawTrol Playwright Validation Plan + Current Baseline (2026-02-16)

## 1) Inventory Baseline (generated from current live code)

Source files:
- `docs/qa/endpoint_inventory.txt` (all routes)
- `docs/qa/endpoint_inventory_api_v1.txt`
- `docs/qa/endpoint_inventory_web.txt`
- `docs/qa/button_inventory.txt`
- `docs/qa/button_inventory_by_file.txt`
- `docs/qa/modal_inventory.txt`
- `docs/qa/modal_inventory_by_file.txt`

Counts:
- Endpoints total: 423
- API v1 endpoints: 133
- Web endpoints: 290
- Button references in code: 720
- Modal/dialog references in code: 481

## 2) Merge Scope Baseline (playground -> origin/main)

Source files:
- `docs/qa/commit_range_playground_to_origin.log`
- `docs/qa/changed_files_playground_to_origin.txt`
- `docs/qa/commit_range_first20.txt`
- `docs/qa/commit_range_last20.txt`

Current status:
- `playground/main` is ancestor of `origin/main`: YES
- Ahead from playground to origin/main: 248 commits
- Non-merge commit lines in log file: 246
- Changed files in range: 57

## 3) Backlog Progress Snapshot

Source files:
- `docs/qa/backlog_checked_items.txt`
- `docs/qa/backlog_unchecked_items.txt`

Current count in `FACTORY_BACKLOG.md`:
- Checked: 72
- Unchecked: 28

## 4) Smoke Validation Already Executed (this session)

### Route smoke (Playwright)
Validated routes (HTTP 200 + no Rails exception page):
- `/boards/1`
- `/pipeline`
- `/marketing`
- `/saved_links`
- `/canvas`
- `/gateway/config`
- `/audits`
- `/outputs`
- `/sessions`

### UI interaction smoke
- Board inline add: `Inbox -> Add a card` opens quick-add row correctly.
- Task detail page (`/boards/1/tasks/67`) shows functional controls:
  - model selector
  - priority selector
  - recurring toggle + recurrence fields
  - nightly toggle + delay
  - agent section visible

### Automated test run (Rails)
Command:
- `bundle exec rails test test/system/task_modal_pipeline_strip_test.rb test/controllers/pipeline_dashboard_controller_test.rb test/jobs/process_saved_link_job_test.rb`

Result:
- 17 runs
- 41 assertions
- 0 failures / 0 errors / 0 skips

## 5) Full Playwright Test Plan (for complete post-merge confidence)

### Suite A: Route Integrity (P0)
Goal:
- Verify every GET web route in `endpoint_inventory_web.txt` resolves without 5xx and without exception page.

Checks:
- HTTP status not in 5xx
- Body does not contain: `ActionController::`, `Routing Error`, `We're sorry, but something went wrong`
- Screenshot on failure

### Suite B: Critical Navigation + Boards (P0)
Goal:
- Validate top nav, board tabs, filters, and kanban load behavior.

Checks:
- Top nav links open expected pages.
- Board tabs remain in dedicated row and are clickable.
- Filter controls update task list without JS errors.
- Realtime badge and queue/running badges render.

### Suite C: Task Lifecycle UI (P0)
Goal:
- Validate task-level controls that drive orchestration intent.

Checks (same task, then reload and re-open):
- Change `model` and verify persistence.
- Change `priority` and verify persistence + activity log entry.
- Toggle `recurring`, set cadence/time, verify next run shown and persisted.
- Toggle `nightly`, set delay, verify badge/state persisted.
- Assign agent persona from modal and verify it is visible in modal + card.
- Remove assigned persona from modal (X/remove control) and verify persistence.

### Suite D: Kanban Operations (P1)
Goal:
- Validate board mechanics after large merge.

Checks:
- Drag/drop across columns updates status badge and column counts.
- No stale UI; board refreshes state without manual F5 after status-changing operations.
- Follow-up action keeps same task/card semantics (no unnecessary card explosion).

### Suite E: Pipeline/Runner Visibility (P1)
Goal:
- Validate pipeline log + execution visibility for operator reporting.

Checks:
- Pipeline stepper and logs render in task panel.
- Agent Activity panel loads without empty/frozen state when events exist.
- `needs_follow_up` and outcome badge are visible and coherent.

### Suite F: Changed-Area Regression Pack (P0/P1)
Target changed areas from `changed_files_playground_to_origin.txt`:
- `saved_links` views + controllers
- pipeline dashboard
- task panel/modal partials
- gateway config page
- model routing / auto-runner services (UI visibility + endpoint behavior)

Checks:
- Exercise at least one happy-path and one edit-path per changed feature area.
- Capture console/network errors and attach to report.

## 6) Exit Criteria

Release confidence is acceptable only if:
- P0 suites pass fully.
- No uncaught JS errors on board/task critical flows.
- No Rails exception pages in route sweep.
- Task modal controls (`model`, `priority`, `recurring`, `nightly`, agent persona assign/remove) are proven persistent end-to-end.

## 7) Current Gaps To Run Next

Not fully executed yet in this pass:
- Exhaustive all-route GET sweep across all 290 web endpoints.
- Full assign/remove persona roundtrip in modal with a known persona fixture.
- Full drag/drop + follow-up same-task regression in one scripted Playwright scenario.
