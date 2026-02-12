# ClawDeck Agent Integration Guide

Complete documentation for integrating OpenClaw agents with ClawDeck.

## Overview

ClawDeck is a Rails 8 + Hotwire kanban board designed for AI agent task management. It provides:

- Task queue with assignment workflow
- Live agent activity tracking (real-time transcript view)
- Model routing for different AI providers
- Follow-up task system
- Nightly/scheduled task support
- Recurring task templates

## Authentication

### API Token

Each user has a unique API token. Find it in **Settings → OpenClaw Integration**.

```bash
# All requests require Bearer token
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Agent-Name: Otacon" \
     -H "X-Agent-Emoji: 📟" \
     https://clawdeck.example.com/api/v1/tasks
```

### Agent Identification Headers

Include these headers with every request:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Agent-Name` | Agent's display name | `Otacon` |
| `X-Agent-Emoji` | Agent's emoji identifier | `📟` |

These headers update the "Connected Agent" display in Settings and show activity timestamps.

## API Reference

### Base URL

```
/api/v1
```

### Task Endpoints

#### List Tasks

```http
GET /tasks
GET /tasks?assigned=true
GET /tasks?status=in_progress
```

**Query Parameters:**
- `assigned=true` — Only tasks assigned to the authenticated agent
- `status=X` — Filter by status (inbox, up_next, in_progress, in_review, done)

**Response:** Array of task objects

#### Get Single Task

```http
GET /tasks/:id
```

#### Create Task

```http
POST /tasks
Content-Type: application/json

{
  "name": "Task title",
  "description": "Task details",
  "status": "inbox",
  "priority": "medium",
  "model": "opus"
}
```

#### Update Task

```http
PATCH /tasks/:id
Content-Type: application/json

{
  "status": "in_progress",
  "agent_session_id": "session-uuid-here",
  "description": "Updated with results..."
}
```

#### Delete Task

```http
DELETE /tasks/:id
```

#### Complete Task

```http
PATCH /tasks/:id/complete
```

Sets status to `done` and records completion timestamp.

#### Claim/Unclaim Task

```http
PATCH /tasks/:id/claim
PATCH /tasks/:id/unclaim
```

Self-assignment for agents.

#### Assign/Unassign Task (Admin)

```http
PATCH /tasks/:id/assign
PATCH /tasks/:id/unassign
```

### Agent-Specific Endpoints

#### Get Agent Transcript

```http
GET /tasks/:id/agent_log
GET /tasks/:id/agent_log?since=1707000000
```

Returns transcript messages from the agent working on this task. Requires `agent_session_id` to be set on the task.

**Query Parameters:**
- `since=TIMESTAMP` — Only return messages after this Unix timestamp (for polling efficiency)

**Response:**
```json
{
  "messages": [
    {
      "role": "user",
      "content": "...",
      "timestamp": 1707000000
    },
    {
      "role": "assistant", 
      "content": "...",
      "timestamp": 1707000001
    }
  ],
  "session_id": "...",
  "last_updated": 1707000001
}
```

#### Generate Follow-up Suggestion

```http
POST /tasks/:id/generate_followup
```

AI analyzes the completed task and suggests follow-up actions.

**Response:**
```json
{
  "suggestion": "Based on the task results, you might want to...",
  "proposed_name": "Follow-up: Review implementation",
  "proposed_status": "inbox"
}
```

#### Create Follow-up Task

```http
POST /tasks/:id/create_followup
Content-Type: application/json

{
  "name": "Follow-up task name",
  "description": "Details...",
  "status": "inbox",
  "model": "sonnet"
}
```

Creates a new task linked to the parent via `parent_task_id`. Inherits model preference if not specified.

#### List Recurring Templates

```http
GET /tasks/recurring
```

Returns tasks with `recurring: true` that serve as templates for auto-recreation.

## Task Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Unique identifier |
| `name` | string | Task title (required) |
| `description` | text | Task details/notes |
| `status` | string | inbox, up_next, in_progress, in_review, done |
| `priority` | string | none, low, medium, high |
| `model` | string | opus, sonnet, codex, gemini, glm (or null) |
| `board_id` | integer | Board this task belongs to |
| `agent_session_id` | string | OpenClaw session ID for live tracking |
| `parent_task_id` | integer | Links follow-up to original task |
| `assigned_at` | datetime | When task was assigned |
| `completed_at` | datetime | When task was completed |
| `blocked` | boolean | Task is blocked, needs human help |
| `nightly` | boolean | Runs on "good night" trigger |
| `nightly_delay_hours` | integer | Hours to delay nightly execution |
| `recurring` | boolean | Template for auto-recreation |
| `recurrence_rule` | string | daily, weekly, monthly |
| `recurrence_time` | string | HH:MM for scheduled execution |
| `created_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Last update timestamp |

## Agent Workflow

### Standard Task Processing

```
1. Poll for assigned tasks (on heartbeat)
   GET /tasks?assigned=true

2. Pick oldest task (first in response array)

3. Start working
   PATCH /tasks/:id { "status": "in_progress" }

4. Spawn sub-agent with task's model
   (See Model Routing below)

5. Save session ID for live tracking
   PATCH /tasks/:id { "agent_session_id": "<real-session-id>" }

6. Work on task...

7. Complete task
   PATCH /tasks/:id { 
     "status": "in_review",
     "description": "Original description\n\n---\n\n## Results\n..."
   }

8. Optionally propose follow-up
   POST /tasks/:id/generate_followup
```

### ⚠️ Critical: Session ID Mapping

When spawning sub-agents in OpenClaw, there's a critical gotcha:

1. `sessions_spawn` returns a `childSessionKey` (e.g., `"agent:main:subagent:UUID-A"`)
2. The transcript API uses a **different** `sessionId`
3. You must call `sessions_list` after spawning to get the actual sessionId
4. Save **that** sessionId to the `agent_session_id` field

**Wrong approach:**
```
spawn → get childSessionKey → save to agent_session_id
```

**Correct approach:**
```
spawn → get childSessionKey → sessions_list → find matching session → get sessionId → save to agent_session_id
```

Without this, the live activity view won't work because it queries transcripts by sessionId.

## Model Routing

Tasks can specify a preferred model. Map these to your agent spawn calls:

| Task Model | Full Model Name | Use Case |
|------------|-----------------|----------|
| `opus` | `anthropic/claude-opus-4` | Complex reasoning, orchestration |
| `sonnet` | `anthropic/claude-sonnet-4` | General purpose, balanced |
| `codex` | `openai/codex-1` | Code generation, refactoring |
| `gemini` | `google/gemini-2.5-pro` | Research, analysis |
| `glm` | `zhipu/glm-4.7` | Simple tasks, bulk operations |

**Implementation:**

```javascript
const modelMap = {
  opus: 'anthropic/claude-opus-4',
  sonnet: 'anthropic/claude-sonnet-4',
  codex: 'openai/codex-1',
  gemini: 'google/gemini-2.5-pro',
  glm: 'zhipu/glm-4.7'
};

const spawnModel = modelMap[task.model] || 'anthropic/claude-sonnet-4';
```

## Follow-up System

Tasks can link to parent tasks via `parent_task_id`. This enables:

1. **Context inheritance** — Follow-ups can reference parent results
2. **Model inheritance** — Defaults to parent's model preference
3. **Visual hierarchy** — UI shows task relationships

### Workflow

```
1. Complete a task

2. Agent suggests follow-up
   POST /tasks/:id/generate_followup
   
3. Human reviews suggestion in UI

4. Human creates follow-up (context menu → Create Follow-up)
   - Picks destination: inbox, up_next, in_progress, nightly
   
5. New task created with parent_task_id linking back
```

## Nightly Tasks

Tasks with `nightly: true` are designed for batch processing:

- **Triggered by:** User saying "good night" or scheduled automation
- **Optional delay:** `nightly_delay_hours` staggers execution
- **Use cases:** Backups, reports, cleanup, analysis

### Processing Nightly Queue

```javascript
// Get nightly tasks
const nightlyTasks = await fetch('/api/v1/tasks?nightly=true');

// Sort by delay (0 first, then 1, 2, etc.)
tasks.sort((a, b) => (a.nightly_delay_hours || 0) - (b.nightly_delay_hours || 0));

// Process with delays
for (const task of tasks) {
  const delayMs = (task.nightly_delay_hours || 0) * 3600000;
  await sleep(delayMs);
  await processTask(task);
}
```

## Recurring Tasks

Tasks with `recurring: true` serve as templates. When completed, a new instance is auto-created.

| Field | Description |
|-------|-------------|
| `recurring` | Enable auto-recreation |
| `recurrence_rule` | daily, weekly, monthly |
| `recurrence_time` | HH:MM for scheduled start |

## Live Activity Tracking

The ClawDeck UI can show real-time agent activity when:

1. Task has `agent_session_id` set
2. Agent transcript is accessible via OpenClaw gateway

**UI Features:**
- Live message streaming
- Typing indicators
- Tool usage display
- Thinking/reasoning visibility

## Error Handling

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 401 | Invalid or missing token |
| 403 | Forbidden (not your task) |
| 404 | Task not found |
| 422 | Validation error |
| 500 | Server error |

### Error Response Format

```json
{
  "error": "Task not found",
  "code": "not_found"
}
```

## Best Practices

1. **Poll on heartbeat, not constantly** — 30-60 second intervals are fine
2. **Always save real sessionId** — Use sessions_list after spawn
3. **Update description with results** — Append to original, don't replace
4. **Set blocked when stuck** — Human will unblock and help
5. **Create tasks for ideas** — Don't forget things you notice
6. **Use model routing** — Match complexity to capability
7. **Propose follow-ups** — Keep momentum going

## Example: Full Task Processing

```javascript
async function processClawDeckTasks() {
  // 1. Get assigned tasks
  const response = await fetch('/api/v1/tasks?assigned=true', {
    headers: {
      'Authorization': `Bearer ${API_TOKEN}`,
      'X-Agent-Name': 'Otacon',
      'X-Agent-Emoji': '📟'
    }
  });
  
  const tasks = await response.json();
  if (tasks.length === 0) return;
  
  // 2. Pick oldest (first in list)
  const task = tasks[0];
  
  // 3. Mark in progress
  await fetch(`/api/v1/tasks/${task.id}`, {
    method: 'PATCH',
    headers: { 
      'Authorization': `Bearer ${API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ status: 'in_progress' })
  });
  
  // 4. Spawn sub-agent with model
  const model = modelMap[task.model] || 'anthropic/claude-sonnet-4';
  const spawnResult = await sessionsSpawn({ model, prompt: task.description });
  
  // 5. Get REAL session ID
  const sessions = await sessionsList();
  const realSession = sessions.find(s => s.key === spawnResult.childSessionKey);
  
  // 6. Save session ID for live tracking
  await fetch(`/api/v1/tasks/${task.id}`, {
    method: 'PATCH',
    headers: { 
      'Authorization': `Bearer ${API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ agent_session_id: realSession.sessionId })
  });
  
  // 7. Wait for completion...
  const result = await waitForCompletion(realSession.sessionId);
  
  // 8. Update with results
  await fetch(`/api/v1/tasks/${task.id}`, {
    method: 'PATCH',
    headers: { 
      'Authorization': `Bearer ${API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ 
      status: 'in_review',
      description: `${task.description}\n\n---\n\n## Results\n\n${result}`
    })
  });
}
```

## Changelog

- **2024-02-04:** Initial documentation
  - API reference
  - Session ID mapping critical note
  - Model routing
  - Follow-up system
  - Nightly tasks
  - Live activity tracking
