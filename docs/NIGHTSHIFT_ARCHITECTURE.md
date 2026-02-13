# Nightshift System Architecture

> Last updated: 2026-02-13 by ClawTrol refactor session

## Overview

Nightshift is the automated overnight task execution system bridging **ClawTrol** (UI/management) and **OpenClaw** (agent execution). Missions are defined in ClawTrol, scheduled nightly, and executed by OpenClaw crons.

## Key Architecture: Fire-and-Forget with Callbacks

The system uses an **async fire-and-forget pattern**:

1. **ClawTrol arms missions** via `approve_tonight` or `arm` endpoints
2. **NightshiftRunnerJob** wakes OpenClaw for each armed selection, then **returns immediately**
3. **OpenClaw crons execute** the mission autonomously
4. **OpenClaw reports back** via `POST /api/v1/nightshift/report_execution` with status and result
5. **NightshiftEngineService** updates the selection and mission timestamps on completion

This replaced an older blocking-poll pattern that starved Solid Queue workers.

## Authentication

Two auth mechanisms coexist:

| Endpoint Type | Auth Method | Header |
|---------------|------------|--------|
| API (user-facing) | Bearer token | `Authorization: Bearer <token>` |
| Cron callbacks | Hook token | `X-Hook-Token: <token>` |

**Cron-facing endpoints** (skip Bearer, require Hook token):
- `POST /api/v1/nightshift/report_execution`
- `POST /api/v1/nightshift/sync_crons`
- `POST /api/v1/nightshift/sync_tonight`

The hook token is configured via `HOOKS_TOKEN` env var, accessed as `Rails.application.config.hooks_token`.

## How to Report Execution (for OpenClaw crons)

When a nightshift cron finishes, it must call back to ClawTrol:

```bash
curl -s -X POST http://localhost:4001/api/v1/nightshift/report_execution \
  -H "Content-Type: application/json" \
  -H "X-Hook-Token: $HOOKS_TOKEN" \
  -d '{"mission_name": "MISSION_NAME_HERE", "status": "completed", "result": "Summary of what was done"}'
```

Valid statuses: `completed`, `failed`

The `mission_name` must match the mission's `name` field in ClawTrol exactly.

## Key Components

### Models
- **NightshiftMission** - Definition of a recurring task (name, frequency, days_of_week, category, estimated_minutes)
- **NightshiftSelection** - Tonight's instance of a mission (status: pending/running/completed/failed, launched_at, completed_at)

### Services
- **NightshiftEngineService** - Manages selection lifecycle. `complete_selection(selection, status:, result:)` sets timestamps and updates `mission.last_run_at`
- **NightshiftSyncService** - Shared sync logic for both web and API controllers:
  - `sync_crons` - Imports OpenClaw crons (prefixed "🌙 NS:") as missions + creates tonight's selections
  - `sync_tonight_selections` - Creates pending selections for all due missions

### Jobs
- **NightshiftRunnerJob** - Fire-and-forget: wakes OpenClaw for each armed selection, returns immediately
- **NightshiftTimeoutSweeperJob** - Fails selections stuck in "running" for >45 minutes (run hourly)

### Controllers
- **Api::V1::NightshiftController** - Full API with CRUD, tonight's view, approval, sync, and report_execution
- **NightshiftController** (web) - UI-facing, uses NightshiftSyncService for index page sync

## Important Rules

1. **`last_run_at` is ONLY set on actual completion** - never on approval/arming. This is handled by `NightshiftEngineService#complete_selection`.
2. **Cron endpoints use Hook token auth**, not Bearer. OpenClaw crons don't have API tokens.
3. **NightshiftRunnerJob must never block** - no sleep loops, no polling. Wake and return.
4. **The sweeper job is the safety net** - if a cron never reports back, the sweeper fails it after 45 minutes.

## Mission Frequency Logic

- `always` - Due every night
- `weekly` - Due on specific `days_of_week` (1=Mon..7=Sun)
- `one_time` - Due only if `last_run_at` is nil (never run before)
- `manual` - Never auto-scheduled, only via explicit selection

## API Endpoints Quick Reference

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | /api/v1/nightshift/missions | Bearer | List enabled missions |
| POST | /api/v1/nightshift/missions | Bearer | Create mission |
| PATCH | /api/v1/nightshift/missions/:id | Bearer | Update mission |
| DELETE | /api/v1/nightshift/missions/:id | Bearer | Delete mission |
| GET | /api/v1/nightshift/tonight | Bearer | Tonight's schedule |
| POST | /api/v1/nightshift/tonight/approve | Bearer | Approve/arm tonight |
| POST | /api/v1/nightshift/arm | Bearer | Arm specific missions |
| POST | /api/v1/nightshift/report_execution | Hook | Cron reports completion |
| POST | /api/v1/nightshift/sync_crons | Hook | Sync OpenClaw crons |
| POST | /api/v1/nightshift/sync_tonight | Hook | Create tonight's selections |
| GET | /api/v1/nightshift/selections | Bearer | Tonight's armed selections |
| PATCH | /api/v1/nightshift/selections/:id | Bearer | Update selection status |
