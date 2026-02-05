# ClawTrol Agent Integration Guide

ClawTrol is a mission control dashboard for AI agents. This document covers the complete integration workflow for orchestrators and sub-agents.

---

## Overview

ClawTrol provides:
- **Task queue with assignment workflow** — Human assigns, agent works
- **Multi-board system** — Auto-routing tasks by prefix (e.g., "ClawDeck:" → ClawDeck board)
- **Model routing** — Specify which LLM model handles each task
- **Live transcript view** — Real-time agent activity monitoring
- **Validation system** — Automated and debate-based code review
- **Follow-up system** — Chain tasks with context inheritance
- **Nightly/recurring tasks** — Scheduled batch processing

---

## Authentication

### API Token

Find your token in **Settings → OpenClaw Integration**.

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "X-Agent-Name: Otacon" \
     -H "X-Agent-Emoji: 📟" \
     https://clawdeck.io/api/v1/tasks
```

### Agent Identity Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Agent-Name` | Yes | Agent's display name (e.g., "Otacon") |
| `X-Agent-Emoji` | Yes | Agent's emoji (e.g., "📟") |

These headers update the "Connected Agent" display and attribute activity notes.

---

## Core Workflow: spawn_ready → link_session → agent_complete

This is the **recommended workflow** for orchestrators spawning sub-agents:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Orchestrator receives task (via heartbeat or direct request)        │
│                                                                         │
│ 2. POST /tasks/spawn_ready                                             │
│    → Creates task in_progress + assigned_to_agent: true                │
│    → Returns task_id + auto-detected board                             │
│    → Includes fallback model if requested model is rate-limited        │
│                                                                         │
│ 3. Orchestrator calls sessions_spawn with task details                 │
│    → Injects task_id, API token, and agent_complete instructions       │
│                                                                         │
│ 4. POST /tasks/:id/link_session                                        │
│    → Connects session_id and session_key to task                       │
│    → Enables live transcript view in UI                                │
│                                                                         │
│ 5. Sub-agent works on task                                             │
│    → Has task_id + API token in its prompt context                     │
│                                                                         │
│ 6. Sub-agent calls POST /tasks/:id/agent_complete                      │
│    → Appends output to description                                     │
│    → Moves task to in_review                                           │
│    → Runs validation if configured                                     │
│                                                                         │
│ 7. Human reviews and approves/creates follow-up                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why spawn_ready?

The old workflow required:
1. Poll for assigned tasks
2. Pick one
3. Claim it
4. Start work

With spawn_ready, you:
1. Call one endpoint
2. Get a ready-to-work task
3. Already in_progress, already assigned

**Saves API calls, eliminates race conditions.**

---

## Endpoint Reference

### spawn_ready

Creates a task ready for immediate agent work.

```http
POST /api/v1/tasks/spawn_ready
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "task": {
    "name": "Fix login validation",
    "description": "Users can log in with empty passwords...",
    "model": "opus",
    "priority": "high",
    "tags": ["bug", "auth"]
  }
}
```

**Response:**
```json
{
  "id": 103,
  "name": "Fix login validation",
  "status": "in_progress",
  "assigned_to_agent": true,
  "board_id": 2,
  "model": "opus",
  "fallback_used": false,
  "fallback_note": null,
  "requested_model": "opus"
}
```

**Auto-fallback:** If the requested model is rate-limited, ClawTrol automatically falls back to the next available model and includes a note in the response.

**Board detection:** If `board_id` is not specified, the task name is analyzed:
- "ClawDeck: ..." → ClawDeck board
- "Pedrito: ..." → Pedrito board
- Otherwise → Misc board (or first board)

---

### link_session

Connects an OpenClaw session to a task for live transcript viewing.

```http
POST /api/v1/tasks/:id/link_session
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "session_id": "abc123-session-uuid",
  "session_key": "agent:main:subagent:abc123"
}
```

**Response:**
```json
{
  "success": true,
  "task_id": 103,
  "task": { ... }
}
```

**Critical:** The UI uses `session_id` (not `session_key`) to read transcripts. After spawning:

```javascript
// Wrong: Using session_key from spawn response
const sessionKey = spawnResult.childSessionKey;

// Right: Get session_id from sessions_list
const sessions = await sessionsList();
const session = sessions.find(s => s.key === sessionKey);
const sessionId = session.sessionId;  // ← This is what you need
```

---

### agent_complete

Called by sub-agent when finished working on a task.

```http
POST /api/v1/tasks/:id/agent_complete
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "output": "Fixed the validation bug. Changes:\n- Added empty check\n- Added tests\n- Updated docs",
  "status": "in_review"
}
```

**Response:**
```json
{
  "id": 103,
  "status": "in_review",
  "description": "Original description...\n\n## Agent Output\nFixed the validation bug...",
  "completed_at": "2026-02-05T15:00:00Z"
}
```

**What happens:**
1. Output is appended to description under "## Agent Output"
2. Task moves to `in_review`
3. `completed_at` timestamp is set
4. `agent_claimed_at` is cleared
5. Validation command runs if configured

---

## Model Routing

Tasks can specify a preferred model. ClawTrol supports:

| Model | Full Name | Best For |
|-------|-----------|----------|
| `opus` | anthropic/claude-opus-4 | Complex reasoning, orchestration |
| `sonnet` | anthropic/claude-sonnet-4 | General purpose, balanced |
| `codex` | openai/codex-1 | Code generation, refactoring |
| `gemini` | google/gemini-2.5-pro | Research, analysis |
| `glm` | zhipu/glm-4.7 | Simple tasks, bulk operations |

### Implementation

```javascript
const MODEL_MAP = {
  opus: 'anthropic/claude-opus-4',
  sonnet: 'anthropic/claude-sonnet-4',
  codex: 'openai/codex-1',
  gemini: 'google/gemini-2.5-pro',
  glm: 'zhipu/glm-4.7'
};

const spawnModel = MODEL_MAP[task.model] || 'anthropic/claude-sonnet-4';
```

### Rate Limit Handling

When a model hits its rate limit:

1. **Report the limit:**
```http
POST /api/v1/tasks/:id/report_rate_limit
{
  "model_name": "opus",
  "error_message": "Rate limit exceeded. Try again in 3600 seconds.",
  "auto_fallback": true
}
```

2. **Check model status:**
```http
GET /api/v1/models/status
```

3. **Get best available model:**
```http
POST /api/v1/models/best
{ "requested_model": "opus" }
```

---

## Multi-Board System

ClawTrol supports multiple boards for organizing tasks:

### List Boards

```http
GET /api/v1/boards
```

### Board Auto-Routing

When creating tasks via `spawn_ready`, the board is auto-detected:

| Task Name Pattern | Routes To |
|-------------------|-----------|
| `ClawDeck: ...` | ClawDeck board |
| `Pedrito: ...` | Pedrito board |
| (other) | Misc board |

### Create Board

```http
POST /api/v1/boards
{ "name": "MyProject", "icon": "🚀", "color": "blue" }
```

---

## Validation System

Tasks can have automated validation before moving to `done`.

### Validation Command (Legacy)

Set a shell command that runs after agent_complete:

```http
PATCH /api/v1/tasks/:id
{
  "validation_command": "npm test -- --coverage"
}
```

If the command exits 0, validation passes. Otherwise, task stays in `in_progress`.

### Review Types

New validation system with multiple review types:

| Type | Description |
|------|-------------|
| `command` | Run a shell command |
| `debate` | Multi-model debate review |

#### Start Command Validation

```http
POST /api/v1/tasks/:id/start_validation
{ "command": "pytest tests/" }
```

#### Start Debate Review

```http
POST /api/v1/tasks/:id/run_debate
{
  "style": "quick",
  "focus": "security",
  "models": ["gemini", "claude", "glm"]
}
```

#### Complete Review (Background Job Callback)

```http
POST /api/v1/tasks/:id/complete_review
{
  "status": "passed",
  "result": { "score": 85, "notes": "..." }
}
```

---

## Follow-up System

Tasks can chain together via `parent_task_id`.

### Generate Follow-up Suggestion

```http
POST /api/v1/tasks/:id/generate_followup
```

Returns AI-generated suggestion based on task results.

### Create Follow-up Task

```http
POST /api/v1/tasks/:id/create_followup
{
  "followup_name": "Deploy fixes to staging",
  "followup_description": "Push the auth fixes to staging environment..."
}
```

Creates a new task linked to the parent. The parent task is auto-completed.

---

## Nightly Tasks

Tasks with `nightly: true` are designed for batch processing:

```http
POST /api/v1/tasks
{
  "task": {
    "name": "Nightly backup validation",
    "nightly": true,
    "nightly_delay_hours": 1
  }
}
```

- **Triggered by:** User saying "good night" or scheduled automation
- **Delay:** `nightly_delay_hours` staggers execution (0, 1, 2 hours...)
- **Use cases:** Backups, reports, cleanup, analysis

---

## Recurring Tasks

Tasks with `recurring: true` auto-recreate when completed:

```http
POST /api/v1/tasks
{
  "task": {
    "name": "Weekly status report",
    "recurring": true,
    "recurrence_rule": "weekly",
    "recurrence_time": "09:00"
  }
}
```

| Field | Values |
|-------|--------|
| `recurrence_rule` | daily, weekly, monthly |
| `recurrence_time` | HH:MM (24-hour format) |

---

## Task Statuses

| Status | Who Moves Here | Description |
|--------|----------------|-------------|
| `inbox` | Human | Ideas, backlog |
| `up_next` | Human | Ready for assignment |
| `in_progress` | Agent | Actively working |
| `in_review` | Agent | Needs human review |
| `done` | Human | Approved and complete |
| `archived` | Human | Completed and hidden |

---

## Error Handling

### Task Error State

When an agent encounters an error:

```http
PATCH /api/v1/tasks/:id
{
  "error_message": "API timeout after 30s",
  "error_at": "2026-02-05T15:00:00Z"
}
```

### Handoff to Different Model

If a task fails with one model, hand off to another:

```http
POST /api/v1/tasks/:id/handoff
{
  "model": "sonnet",
  "include_transcript": true
}
```

---

## OpenClaw Webhook Integration

ClawTrol can trigger OpenClaw agents for urgent tasks:

1. Configure in **Settings → OpenClaw Integration**
2. Set Gateway URL and Token
3. Assign a task with "urgent" priority
4. ClawTrol POSTs to OpenClaw's `/webhook/inbound`

---

## Best Practices

1. **Use spawn_ready** — One call instead of poll+claim
2. **Always link_session** — Enables live transcript view
3. **Call agent_complete** — Don't just update status manually
4. **Handle rate limits** — Use model fallback chain
5. **Set validation commands** — Automate quality checks
6. **Use model routing** — Match task complexity to model capability
7. **Create follow-ups** — Keep momentum going

---

## Example: Complete Orchestrator Flow

```javascript
async function handleTask(taskRequest) {
  const API = 'http://192.168.100.186:4001/api/v1';
  const TOKEN = 'your-api-token';
  
  // 1. Create task ready for work
  const spawnRes = await fetch(`${API}/tasks/spawn_ready`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
      'X-Agent-Name': 'Otacon',
      'X-Agent-Emoji': '📟'
    },
    body: JSON.stringify({
      task: {
        name: taskRequest.name,
        description: taskRequest.description,
        model: 'opus'
      }
    })
  });
  const task = await spawnRes.json();
  
  // 2. Spawn sub-agent
  const spawnResult = await sessionsSpawn({
    model: MODEL_MAP[task.model],
    prompt: buildAgentPrompt(task)
  });
  
  // 3. Get real session ID
  const sessions = await sessionsList();
  const session = sessions.find(s => s.key === spawnResult.childSessionKey);
  
  // 4. Link session for live view
  await fetch(`${API}/tasks/${task.id}/link_session`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      session_id: session.sessionId,
      session_key: session.key
    })
  });
  
  // 5. Sub-agent works (has instructions to call agent_complete when done)
}

function buildAgentPrompt(task) {
  return `
## ClawTrol Task #${task.id}: ${task.name}

**CRITICAL: Save your output before finishing!**
Task ID: ${task.id}
API Base: http://192.168.100.186:4001/api/v1
Token: ${TOKEN}

When done, call:
\`\`\`bash
curl -X POST "${API}/tasks/${task.id}/agent_complete" \\
  -H "Authorization: Bearer ${TOKEN}" \\
  -H "Content-Type: application/json" \\
  -d '{"output": "YOUR_SUMMARY_HERE", "status": "in_review"}'
\`\`\`

---

${task.description}
`;
}
```

---

## Changelog

- **2026-02-05:** Major rewrite for ClawTrol
  - spawn_ready workflow
  - link_session endpoint
  - agent_complete endpoint
  - Multi-board system
  - Model routing and fallback
  - Validation system (command + debate)
  - Updated branding
