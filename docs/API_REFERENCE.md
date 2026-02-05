# ClawTrol API Reference

Complete API endpoint documentation for ClawTrol.

**Base URL:** `/api/v1`

**Authentication:** `Authorization: Bearer YOUR_TOKEN`

**Agent Headers (recommended):**
```
X-Agent-Name: Otacon
X-Agent-Emoji: 📟
```

---

## Tasks

### List Tasks

```http
GET /tasks
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `board_id` | integer | Filter by board |
| `status` | string | Filter by status: inbox, up_next, in_progress, in_review, done |
| `assigned` | boolean | Filter by agent assignment |
| `blocked` | boolean | Filter by blocked state |
| `completed` | boolean | Filter by completion state |
| `priority` | string | Filter by priority: none, low, medium, high |
| `tag` | string | Filter by tag name |

**Example:**
```http
GET /tasks?assigned=true&status=up_next
```

**Response:**
```json
[
  {
    "id": 103,
    "name": "Fix login bug",
    "description": "...",
    "status": "up_next",
    "priority": "high",
    "blocked": false,
    "assigned_to_agent": true,
    "assigned_at": "2026-02-05T14:00:00Z",
    "board_id": 2,
    "model": "opus",
    "tags": ["bug", "auth"],
    "created_at": "2026-02-05T13:00:00Z",
    "updated_at": "2026-02-05T14:00:00Z"
  }
]
```

---

### Get Task

```http
GET /tasks/:id
```

**Response:** Full task object (see schema below)

---

### Create Task

```http
POST /tasks
Content-Type: application/json

{
  "task": {
    "name": "Task title",
    "description": "Task details",
    "status": "inbox",
    "priority": "medium",
    "board_id": 2,
    "model": "sonnet",
    "tags": ["feature"]
  }
}
```

**Response:** Created task object

---

### Update Task

```http
PATCH /tasks/:id
Content-Type: application/json

{
  "task": {
    "status": "in_progress",
    "agent_session_id": "session-uuid"
  },
  "activity_note": "Starting work on this!"
}
```

**Response:** Updated task object

---

### Delete Task

```http
DELETE /tasks/:id
```

**Response:** `204 No Content`

---

### spawn_ready

Creates a task ready for immediate agent work (in_progress + assigned).

```http
POST /tasks/spawn_ready
Content-Type: application/json

{
  "task": {
    "name": "Fix validation bug",
    "description": "Users can submit empty forms...",
    "model": "opus",
    "priority": "high",
    "tags": ["bug"]
  }
}
```

**Response:**
```json
{
  "id": 104,
  "name": "Fix validation bug",
  "status": "in_progress",
  "assigned_to_agent": true,
  "board_id": 2,
  "model": "opus",
  "fallback_used": false,
  "fallback_note": null,
  "requested_model": "opus",
  ...
}
```

**Notes:**
- Auto-detects board based on task name prefix
- Auto-fallback if requested model is rate-limited
- Sets status to `in_progress` and `assigned_to_agent: true`

---

### link_session

Links OpenClaw session to task for live transcript view.

```http
POST /tasks/:id/link_session
Content-Type: application/json

{
  "session_id": "abc123-session-uuid",
  "session_key": "agent:main:subagent:abc123"
}
```

**Response:**
```json
{
  "success": true,
  "task_id": 104,
  "task": { ... }
}
```

**Important:** Use the real `session_id` from sessions_list, not the `session_key` from spawn.

---

### agent_complete

Called by sub-agent when finished working.

```http
POST /tasks/:id/agent_complete
Content-Type: application/json

{
  "output": "Fixed the bug. Changes:\n- Added validation\n- Added tests",
  "status": "in_review"
}
```

**Response:**
```json
{
  "id": 104,
  "status": "in_review",
  "description": "Original...\n\n## Agent Output\nFixed the bug...",
  "completed_at": "2026-02-05T15:00:00Z",
  ...
}
```

**What happens:**
- Appends output under "## Agent Output"
- Moves to `in_review`
- Sets `completed_at`
- Clears `agent_claimed_at`
- Runs validation command if configured

---

### agent_log

Get agent transcript for a task. **No authentication required** (task ID is the secret).

```http
GET /tasks/:id/agent_log
GET /tasks/:id/agent_log?since=100
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `since` | integer | Only return messages after this line number |

**Response:**
```json
{
  "messages": [
    {
      "id": "msg-1",
      "line": 1,
      "timestamp": "2026-02-05T14:00:00Z",
      "role": "user",
      "content": [{"type": "text", "text": "..."}]
    },
    {
      "id": "msg-2",
      "line": 2,
      "timestamp": "2026-02-05T14:00:01Z",
      "role": "assistant",
      "content": [
        {"type": "thinking", "text": "..."},
        {"type": "text", "text": "..."},
        {"type": "tool_call", "name": "Read", "id": "tc-1"}
      ]
    }
  ],
  "total_lines": 50,
  "since": 0,
  "has_session": true,
  "task_status": "in_progress"
}
```

---

### session_health

Check agent session health for continuation decisions. **No authentication required.**

```http
GET /tasks/:id/session_health
```

**Response:**
```json
{
  "alive": true,
  "context_percent": 45,
  "recommendation": "continue",
  "threshold": 70,
  "session_key": "agent:main:subagent:abc123"
}
```

| Recommendation | Meaning |
|----------------|---------|
| `continue` | Session has context headroom |
| `fresh` | Session should be restarted |

---

### complete

Toggle task between done and inbox.

```http
PATCH /tasks/:id/complete
```

**Response:** Updated task object

---

### claim / unclaim

Agent claims or releases a task.

```http
PATCH /tasks/:id/claim
PATCH /tasks/:id/unclaim
```

**claim:** Sets `agent_claimed_at`, moves to `in_progress`
**unclaim:** Clears `agent_claimed_at`

---

### assign / unassign

Assign or unassign task to/from agent.

```http
PATCH /tasks/:id/assign
PATCH /tasks/:id/unassign
```

---

### move

Move task to different status column.

```http
PATCH /tasks/:id/move
Content-Type: application/json

{
  "status": "up_next"
}
```

---

### handoff

Hand off task to a different model.

```http
POST /tasks/:id/handoff
Content-Type: application/json

{
  "model": "sonnet",
  "include_transcript": true
}
```

**Response:**
```json
{
  "task": { ... },
  "handoff_context": {
    "task_id": 104,
    "previous_model": "opus",
    "new_model": "sonnet",
    "error_message": "Rate limit exceeded",
    "transcript_preview": "..."
  }
}
```

---

### report_rate_limit

Report a rate limit for a model, optionally trigger fallback.

```http
POST /tasks/:id/report_rate_limit
Content-Type: application/json

{
  "model_name": "opus",
  "error_message": "Rate limit exceeded. Try again in 3600 seconds.",
  "resets_at": "2026-02-05T16:00:00Z",
  "auto_fallback": true
}
```

**Response:**
```json
{
  "task": { ... },
  "model_limit": {
    "model": "opus",
    "limited": true,
    "resets_at": "2026-02-05T16:00:00Z",
    "resets_in": "45 minutes"
  },
  "fallback_used": true,
  "fallback_note": "⚠️ opus rate-limited. Using sonnet.",
  "new_model": "sonnet"
}
```

---

### generate_followup

Generate AI suggestion for follow-up task.

```http
POST /tasks/:id/generate_followup
```

**Response:**
```json
{
  "suggested_followup": "Based on the implementation, consider:\n1. Add integration tests\n2. Update documentation\n3. Deploy to staging",
  "task": { ... }
}
```

---

### enhance_followup

Enhance a draft follow-up description with AI.

```http
POST /tasks/:id/enhance_followup
Content-Type: application/json

{
  "draft": "Deploy the changes"
}
```

**Response:**
```json
{
  "enhanced": "Deploy the authentication fix to staging environment:\n1. Run migrations\n2. Verify login flow\n3. Check error rates"
}
```

---

### create_followup

Create a follow-up task linked to parent.

```http
POST /tasks/:id/create_followup
Content-Type: application/json

{
  "followup_name": "Deploy to staging",
  "followup_description": "Push the auth fix to staging..."
}
```

**Response:**
```json
{
  "followup": {
    "id": 105,
    "name": "Deploy to staging",
    "parent_task_id": 104,
    ...
  },
  "source_task": {
    "id": 104,
    "status": "done",
    ...
  }
}
```

**Note:** Source task is auto-completed when follow-up is created.

---

### start_validation

Start command-based validation review.

```http
POST /tasks/:id/start_validation
Content-Type: application/json

{
  "command": "npm test -- --coverage"
}
```

**Response:**
```json
{
  "task": { ... },
  "review_status": "pending",
  "message": "Validation started"
}
```

Runs in background via `RunValidationJob`.

---

### revalidate

Re-run the validation command.

```http
POST /tasks/:id/revalidate
```

Requires `validation_command` to be set on the task.

---

### run_debate

Start multi-model debate review.

```http
POST /tasks/:id/run_debate
Content-Type: application/json

{
  "style": "quick",
  "focus": "security",
  "models": ["gemini", "claude", "glm"]
}
```

**Parameters:**

| Field | Description |
|-------|-------------|
| `style` | Review depth: quick, thorough |
| `focus` | Optional focus area: security, performance, correctness |
| `models` | Array of models to use (default: gemini, claude, glm) |

---

### complete_review

Complete a review with result (called by background job).

```http
POST /tasks/:id/complete_review
Content-Type: application/json

{
  "status": "passed",
  "result": {
    "score": 85,
    "notes": "Minor issues found",
    "recommendations": ["Add error handling"]
  }
}
```

---

### recurring

List recurring task templates.

```http
GET /tasks/recurring
```

Returns tasks with `recurring: true`.

---

### next

Get next task for auto-mode agent.

```http
GET /tasks/next
```

Returns highest priority unclaimed task in `up_next`, or `204 No Content`.

---

### pending_attention

Get tasks in_progress that agent claimed.

```http
GET /tasks/pending_attention
```

---

### errored_count

Get count of errored tasks (for badge).

```http
GET /tasks/errored_count
```

**Response:**
```json
{
  "count": 3
}
```

---

## Boards

### List Boards

```http
GET /boards
```

**Response:**
```json
[
  {
    "id": 1,
    "name": "ClawDeck",
    "icon": "🦀",
    "color": "red",
    "tasks_count": 12,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-05T00:00:00Z"
  }
]
```

---

### Get Board

```http
GET /boards/:id
GET /boards/:id?include_tasks=true
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `include_tasks` | boolean | Include tasks array in response |

---

### Get Board Status

Lightweight endpoint for polling changes.

```http
GET /boards/:id/status
```

**Response:**
```json
{
  "fingerprint": "abc123",
  "task_count": 12,
  "updated_at": "2026-02-05T15:00:00Z"
}
```

Compare fingerprint to detect changes without fetching all tasks.

---

### Create Board

```http
POST /boards
Content-Type: application/json

{
  "name": "MyProject",
  "icon": "🚀",
  "color": "blue"
}
```

**Colors:** gray, red, blue, lime, purple, yellow

---

### Update Board

```http
PATCH /boards/:id
Content-Type: application/json

{
  "name": "New Name",
  "icon": "🎯"
}
```

---

### Delete Board

```http
DELETE /boards/:id
```

**Note:** Cannot delete your only board.

---

## Model Limits

### Get Model Status

```http
GET /models/status
```

**Response:**
```json
{
  "models": [
    {"model": "opus", "available": false, "limited": true, "resets_at": "2026-02-05T16:00:00Z", "resets_in": "45 minutes"},
    {"model": "sonnet", "available": true, "limited": false},
    {"model": "codex", "available": true, "limited": false},
    {"model": "gemini", "available": true, "limited": false},
    {"model": "glm", "available": true, "limited": false}
  ],
  "priority_order": ["opus", "sonnet", "codex", "gemini", "glm"],
  "fallback_chain": ["opus", "sonnet", "codex", "gemini", "glm"]
}
```

---

### Get Best Available Model

```http
POST /models/best
Content-Type: application/json

{
  "requested_model": "opus"
}
```

**Response:**
```json
{
  "model": "sonnet",
  "requested": "opus",
  "fallback_used": true,
  "fallback_note": "⚠️ opus rate-limited. Using sonnet instead."
}
```

---

### Record Rate Limit

```http
POST /models/:model_name/limit
Content-Type: application/json

{
  "error_message": "Rate limit exceeded. Try again in 3600 seconds.",
  "resets_at": "2026-02-05T16:00:00Z"
}
```

---

### Clear Rate Limit

```http
DELETE /models/:model_name/limit
```

---

## Settings

### Get Settings

```http
GET /settings
```

---

### Update Settings

```http
PATCH /settings
Content-Type: application/json

{
  "agent_auto_mode": true,
  "context_threshold_percent": 70
}
```

---

## Task Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Unique identifier |
| `name` | string | Task title (required) |
| `description` | text | Task details/notes |
| `status` | string | inbox, up_next, in_progress, in_review, done |
| `priority` | string | none, low, medium, high |
| `blocked` | boolean | Task is blocked |
| `completed` | boolean | Task is complete |
| `completed_at` | datetime | Completion timestamp |
| `due_date` | date | Due date |
| `position` | integer | Sort order within status |
| `board_id` | integer | Board this task belongs to |
| `parent_task_id` | integer | Parent task (for follow-ups) |
| `followup_task_id` | integer | Follow-up task ID |
| `tags` | array | Tag strings |
| `model` | string | opus, sonnet, codex, gemini, glm |
| `assigned_to_agent` | boolean | Assigned to agent |
| `assigned_at` | datetime | Assignment timestamp |
| `agent_claimed_at` | datetime | When agent claimed |
| `agent_session_id` | string | OpenClaw session UUID |
| `agent_session_key` | string | OpenClaw session key |
| `context_usage_percent` | integer | Context usage estimate |
| `nightly` | boolean | Run on "good night" |
| `nightly_delay_hours` | integer | Hours to delay |
| `recurring` | boolean | Recurring template |
| `recurrence_rule` | string | daily, weekly, monthly |
| `recurrence_time` | string | HH:MM schedule |
| `next_recurrence_at` | datetime | Next scheduled run |
| `error_message` | string | Last error |
| `error_at` | datetime | Error timestamp |
| `retry_count` | integer | Retry attempts |
| `suggested_followup` | text | AI-generated suggestion |
| `validation_command` | string | Shell command to run |
| `validation_status` | string | pending, passed, failed |
| `validation_output` | text | Command output |
| `review_type` | string | command, debate |
| `review_status` | string | pending, passed, failed |
| `review_config` | json | Review configuration |
| `review_result` | json | Review result data |
| `url` | string | Web UI URL |
| `created_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Last update |

---

## Error Responses

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 401 | Invalid or missing token |
| 403 | Forbidden |
| 404 | Not found |
| 422 | Validation error |
| 500 | Server error |

**Error format:**
```json
{
  "error": "Task not found"
}
```

**Validation error format:**
```json
{
  "errors": {
    "name": ["can't be blank"]
  }
}
```
