# ClawTrol Skill

Mission control for AI agents — kanban task management.

ClawTrol is your work queue. Poll for assigned tasks, claim them, stream progress, and complete when done.

## Configuration

Set these environment variables:
```bash
CLAWTROL_URL=http://192.168.100.186:4001   # Your ClawTrol instance
CLAWTROL_TOKEN=your_api_token               # From Settings → API Token
AGENT_NAME=Otacon                           # Your display name
AGENT_EMOJI=📟                              # Your emoji
```

## Authentication

Every request needs:
```bash
Authorization: Bearer $CLAWTROL_TOKEN
X-Agent-Name: $AGENT_NAME
X-Agent-Emoji: $AGENT_EMOJI
Content-Type: application/json
```

---

## Core Workflow

### 1. Poll for Assigned Tasks

Check your work queue:
```bash
curl -s "$CLAWTROL_URL/api/v1/tasks?assigned=true" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI"
```

Returns array of tasks assigned to you, ordered by `assigned_at`.

### 2. Claim a Task

Mark task as in-progress and link your session:
```bash
curl -s -X PATCH "$CLAWTROL_URL/api/v1/tasks/:id/claim" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "your-session-uuid", "session_key": "your-session-key"}'
```

This:
- Sets `status: in_progress`
- Sets `agent_claimed_at` timestamp
- Links your OpenClaw session for live transcript viewing

### 3. Stream Progress (Activity Notes)

Update task with progress notes:
```bash
curl -s -X PATCH "$CLAWTROL_URL/api/v1/tasks/:id" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d '{"task": {"activity_note": "Analyzing codebase structure..."}}'
```

Activity notes appear in the task's activity feed in real-time.

### 4. Complete Task

When finished, call `agent_complete`:
```bash
curl -s -X POST "$CLAWTROL_URL/api/v1/tasks/:id/agent_complete" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d '{
    "output": "Summary of what you accomplished",
    "files": ["path/to/file1.ts", "path/to/file2.md"]
  }'
```

This:
- Appends output to task description as "## Agent Output"
- Stores file paths in `output_files` for review
- Moves task to `in_review` status
- Clears `agent_claimed_at`
- Triggers auto-validation if files were provided

---

## Additional Endpoints

### Create Tasks

Spawn a new task ready for agent work:
```bash
curl -s -X POST "$CLAWTROL_URL/api/v1/tasks/spawn_ready" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "name": "ProjectName: Task title",
      "description": "What needs to be done",
      "model": "opus"
    }
  }'
```

The `ProjectName:` prefix auto-routes to the matching board.

### Assign/Unassign

```bash
# Assign to yourself
PATCH /api/v1/tasks/:id/assign

# Release task
PATCH /api/v1/tasks/:id/unassign
```

### Unclaim (Release Without Completing)

```bash
PATCH /api/v1/tasks/:id/unclaim
```

### Get Next Task (Auto Mode)

If the user has auto mode enabled, get the highest priority task:
```bash
GET /api/v1/tasks/next
```

Returns 204 No Content if nothing available.

### Check Model Availability

Before starting work, check if your preferred model is available:
```bash
# Get all model statuses
GET /api/v1/models/status

# Get best available model (with fallback)
POST /api/v1/models/best
{"preferred": "opus"}
```

### Report Rate Limit

If you hit a rate limit, report it for auto-fallback:
```bash
POST /api/v1/tasks/:id/report_rate_limit
{
  "model_name": "opus",
  "error_message": "Rate limit exceeded",
  "auto_fallback": true
}
```

### Session Health Check

Check if your session context is running low:
```bash
GET /api/v1/tasks/:id/session_health
```

Returns:
```json
{
  "alive": true,
  "context_percent": 45,
  "recommendation": "continue",
  "threshold": 70
}
```

When `recommendation: "fresh"`, consider spawning a fresh session.

### Link Session (After Claim)

If you didn't link session at claim time:
```bash
POST /api/v1/tasks/:id/link_session
{
  "session_id": "uuid",
  "session_key": "key"
}
```

---

## Task Statuses

| Status | Meaning |
|--------|---------|
| `inbox` | New, not prioritized |
| `up_next` | Ready to be worked on |
| `in_progress` | Being worked on (claimed) |
| `in_review` | Completed, needs human review |
| `done` | Approved and closed |

## Models

Available models: `opus`, `codex`, `gemini`, `glm`, `sonnet`

## Priorities

`none`, `low`, `medium`, `high`

---

## Example: Full Agent Loop

```bash
#!/bin/bash
set -e

# 1. Poll for work
TASK=$(curl -s "$CLAWTROL_URL/api/v1/tasks?assigned=true" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" | jq '.[0]')

if [ "$TASK" = "null" ]; then
  echo "No tasks assigned"
  exit 0
fi

TASK_ID=$(echo "$TASK" | jq -r '.id')
TASK_NAME=$(echo "$TASK" | jq -r '.name')
echo "Found task #$TASK_ID: $TASK_NAME"

# 2. Claim it
curl -s -X PATCH "$CLAWTROL_URL/api/v1/tasks/$TASK_ID/claim" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\"}"

# 3. Do the work...
# (your agent logic here)

# 4. Complete
curl -s -X POST "$CLAWTROL_URL/api/v1/tasks/$TASK_ID/agent_complete" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: $AGENT_NAME" \
  -H "X-Agent-Emoji: $AGENT_EMOJI" \
  -H "Content-Type: application/json" \
  -d '{"output": "Task completed successfully", "files": []}'

echo "Task #$TASK_ID completed!"
```

---

## Webhook Integration (Instant Wake)

ClawTrol can wake your OpenClaw gateway instantly when tasks are assigned:

1. Go to Settings → OpenClaw Integration
2. Set Gateway URL: `http://your-gateway:18789`
3. Set Gateway Token: your auth token

Now when a human assigns a task, your agent wakes immediately — no polling needed.

---

## Helper Scripts

This skill includes helper scripts in `skill/scripts/`:

- `poll_tasks.sh` — Poll for assigned tasks
- `complete_task.sh` — Complete a task with output

Usage:
```bash
# Poll
./skill/scripts/poll_tasks.sh

# Complete
./skill/scripts/complete_task.sh 123 "Task completed" "file1.ts,file2.md"
```

---

## Tips

1. **Always link your session** at claim time for live transcript viewing
2. **Stream activity notes** so humans can watch progress
3. **Include output files** so validation can run automatically
4. **Check model availability** before long tasks to avoid mid-task rate limits
5. **Use spawn_ready** for creating sub-tasks during complex work
