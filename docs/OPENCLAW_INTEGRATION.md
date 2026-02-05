# OpenClaw Integration Guide

Step-by-step guide for integrating ClawTrol with OpenClaw agents.

---

## Overview

This guide covers:
1. Configuring HEARTBEAT.md for task polling
2. Using spawn_ready workflow
3. Linking sessions for live transcript view
4. Setting up webhooks for urgent tasks
5. Complete example code

---

## Prerequisites

- OpenClaw agent running (main session)
- ClawTrol instance accessible (default: http://192.168.100.186:4001)
- API token from ClawTrol Settings

---

## 1. HEARTBEAT.md Configuration

Add ClawTrol task checking to your `HEARTBEAT.md`:

```markdown
# HEARTBEAT.md

## ClawTrol Task Check (Every heartbeat)

1. Check for assigned tasks:
   ```bash
   curl -s "http://192.168.100.186:4001/api/v1/tasks?assigned=true" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

2. If tasks exist with status `up_next`:
   - Use spawn_ready workflow (see below)
   - Spawn sub-agent for oldest task

3. Check for errored tasks needing retry:
   ```bash
   curl -s "http://192.168.100.186:4001/api/v1/tasks?status=in_progress" \
     -H "Authorization: Bearer YOUR_TOKEN" | jq '.[] | select(.error_message != null)'
   ```

## When to check
- Every heartbeat (default: 30-60 seconds)
- After receiving OpenClaw webhook
```

---

## 2. spawn_ready Workflow

The spawn_ready workflow is the **recommended approach** for processing tasks.

### Step 1: Create Task Ready for Work

```bash
curl -X POST "http://192.168.100.186:4001/api/v1/tasks/spawn_ready" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Agent-Name: Otacon" \
  -H "X-Agent-Emoji: 📟" \
  -d '{
    "task": {
      "name": "Fix authentication bug",
      "description": "Users can log in with empty passwords...",
      "model": "opus",
      "priority": "high"
    }
  }'
```

**Response:**
```json
{
  "id": 103,
  "name": "Fix authentication bug",
  "status": "in_progress",
  "assigned_to_agent": true,
  "board_id": 2,
  "model": "opus",
  "fallback_used": false
}
```

### Step 2: Build Sub-Agent Prompt

Include task ID, API details, and completion instructions:

```javascript
function buildSubAgentPrompt(task) {
  return `
## ClawTrol Task #${task.id}: ${task.name}

**CRITICAL: Save your output before finishing!**
Task ID: ${task.id}
API Base: http://192.168.100.186:4001/api/v1
Token: ${API_TOKEN}

When done, call:
\`\`\`bash
curl -X POST "http://192.168.100.186:4001/api/v1/tasks/${task.id}/agent_complete" \\
  -H "Authorization: Bearer ${API_TOKEN}" \\
  -H "Content-Type: application/json" \\
  -d '{"output": "YOUR_SUMMARY_HERE", "status": "in_review"}'
\`\`\`

---

${task.description}
`;
}
```

### Step 3: Spawn Sub-Agent

Use OpenClaw's sessions_spawn with the model from the task:

```javascript
const MODEL_MAP = {
  opus: 'anthropic/claude-opus-4',
  sonnet: 'anthropic/claude-sonnet-4',
  codex: 'openai/codex-1',
  gemini: 'google/gemini-2.5-pro',
  glm: 'zhipu/glm-4.7'
};

const spawnResult = await sessionsSpawn({
  model: MODEL_MAP[task.model] || 'anthropic/claude-sonnet-4',
  prompt: buildSubAgentPrompt(task)
});
```

### Step 4: Link Session for Live View

⚠️ **Critical:** Get the REAL session ID, not the session key!

```javascript
// The spawn returns a session_key (e.g., "agent:main:subagent:UUID-A")
// But the transcript API uses session_id (different!)

// Get all sessions
const sessions = await sessionsList();

// Find the one matching our spawn
const session = sessions.find(s => s.key === spawnResult.childSessionKey);

// Link to ClawTrol with the REAL session_id
await fetch(`${API_BASE}/tasks/${task.id}/link_session`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${API_TOKEN}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    session_id: session.sessionId,  // ← This enables live transcript view!
    session_key: session.key
  })
});
```

### Step 5: Sub-Agent Calls agent_complete

The sub-agent (not orchestrator) calls this when finished:

```bash
curl -X POST "http://192.168.100.186:4001/api/v1/tasks/103/agent_complete" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "output": "Fixed the bug. Changes:\n- Added validation\n- Added tests\n- Updated docs",
    "status": "in_review"
  }'
```

---

## 3. Polling Existing Tasks

If you prefer the polling pattern over spawn_ready:

### Check for Assigned Tasks

```bash
# Get tasks assigned to agent, ordered by assignment time
curl -s "http://192.168.100.186:4001/api/v1/tasks?assigned=true&status=up_next" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "X-Agent-Name: Otacon" \
  -H "X-Agent-Emoji: 📟"
```

### Claim and Start Work

```bash
# Claim the task (moves to in_progress)
curl -X PATCH "http://192.168.100.186:4001/api/v1/tasks/103/claim" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Update with Session Info

```bash
curl -X PATCH "http://192.168.100.186:4001/api/v1/tasks/103" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task": {
      "agent_session_id": "real-session-uuid"
    }
  }'
```

---

## 4. Webhook Setup for Urgent Tasks

ClawTrol can push to OpenClaw when urgent tasks are created.

### Configure in ClawTrol

1. Go to **Settings → OpenClaw Integration**
2. Set Gateway URL: `http://192.168.100.186:18789`
3. Set Gateway Token: `your-gateway-token`
4. Enable "Push urgent tasks"

### Webhook Payload

When an urgent task is assigned, ClawTrol sends:

```json
{
  "event": "task.assigned",
  "task": {
    "id": 103,
    "name": "URGENT: Fix production outage",
    "priority": "high",
    "model": "opus"
  }
}
```

### Handle in HEARTBEAT.md

```markdown
## Webhook Handler

If OpenClaw receives a webhook with `event: task.assigned`:
1. Immediately process the task
2. Skip normal heartbeat polling
3. Use spawn_ready workflow
```

---

## 5. Model Fallback Handling

When a model is rate-limited:

### Check Model Status

```bash
curl -s "http://192.168.100.186:4001/api/v1/models/status" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response:**
```json
{
  "models": [
    {"model": "opus", "available": false, "resets_in": "45 minutes"},
    {"model": "sonnet", "available": true},
    {"model": "codex", "available": true},
    {"model": "gemini", "available": true},
    {"model": "glm", "available": true}
  ],
  "priority_order": ["opus", "sonnet", "codex", "gemini", "glm"]
}
```

### Get Best Available Model

```bash
curl -X POST "http://192.168.100.186:4001/api/v1/models/best" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"requested_model": "opus"}'
```

**Response:**
```json
{
  "model": "sonnet",
  "requested": "opus",
  "fallback_used": true,
  "fallback_note": "⚠️ Requested opus but rate-limited. Using sonnet instead."
}
```

### Report Rate Limit

When you hit a limit:

```bash
curl -X POST "http://192.168.100.186:4001/api/v1/tasks/103/report_rate_limit" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "opus",
    "error_message": "Rate limit exceeded. Try again in 3600 seconds.",
    "auto_fallback": true
  }'
```

---

## 6. Complete Example: Orchestrator Code

```javascript
// ClawTrol Orchestrator Integration
const CLAWTROL_API = 'http://192.168.100.186:4001/api/v1';
const CLAWTROL_TOKEN = 'your-api-token';

const MODEL_MAP = {
  opus: 'anthropic/claude-opus-4',
  sonnet: 'anthropic/claude-sonnet-4',
  codex: 'openai/codex-1',
  gemini: 'google/gemini-2.5-pro',
  glm: 'zhipu/glm-4.7'
};

async function processClawTrolTask(taskRequest) {
  // 1. Create task via spawn_ready
  const createRes = await fetch(`${CLAWTROL_API}/tasks/spawn_ready`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CLAWTROL_TOKEN}`,
      'Content-Type': 'application/json',
      'X-Agent-Name': 'Otacon',
      'X-Agent-Emoji': '📟'
    },
    body: JSON.stringify({
      task: {
        name: taskRequest.name,
        description: taskRequest.description,
        model: taskRequest.model || 'sonnet',
        priority: taskRequest.priority || 'medium'
      }
    })
  });
  
  const task = await createRes.json();
  console.log(`Created ClawTrol task #${task.id}`);
  
  // Check if fallback was used
  if (task.fallback_used) {
    console.log(`⚠️ Model fallback: ${task.fallback_note}`);
  }
  
  // 2. Build sub-agent prompt with completion instructions
  const prompt = `
## ClawTrol Task #${task.id}: ${task.name}

**CRITICAL: Save your output before finishing!**
Task ID: ${task.id}
API Base: ${CLAWTROL_API}
Token: ${CLAWTROL_TOKEN}

When done, call:
\`\`\`bash
curl -X POST "${CLAWTROL_API}/tasks/${task.id}/agent_complete" \\
  -H "Authorization: Bearer ${CLAWTROL_TOKEN}" \\
  -H "Content-Type: application/json" \\
  -d '{"output": "YOUR_SUMMARY_HERE", "status": "in_review"}'
\`\`\`

---

## Task Description

${task.description}
`;

  // 3. Spawn sub-agent with appropriate model
  const model = MODEL_MAP[task.model] || 'anthropic/claude-sonnet-4';
  const spawnResult = await sessionsSpawn({ model, prompt });
  
  // 4. Get REAL session ID for live transcript
  const sessions = await sessionsList();
  const session = sessions.find(s => s.key === spawnResult.childSessionKey);
  
  if (!session) {
    console.error('Could not find spawned session!');
    return;
  }
  
  // 5. Link session to task
  await fetch(`${CLAWTROL_API}/tasks/${task.id}/link_session`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CLAWTROL_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      session_id: session.sessionId,
      session_key: session.key
    })
  });
  
  console.log(`Linked session ${session.sessionId} to task #${task.id}`);
  console.log(`Live view: ${CLAWTROL_API.replace('/api/v1', '')}/boards/${task.board_id}/tasks/${task.id}`);
  
  return { task, session };
}

// Check for assigned tasks on heartbeat
async function heartbeatCheck() {
  const res = await fetch(`${CLAWTROL_API}/tasks?assigned=true&status=up_next`, {
    headers: {
      'Authorization': `Bearer ${CLAWTROL_TOKEN}`,
      'X-Agent-Name': 'Otacon',
      'X-Agent-Emoji': '📟'
    }
  });
  
  const tasks = await res.json();
  
  if (tasks.length > 0) {
    // Process oldest assigned task
    const task = tasks[0];
    await processClawTrolTask({
      name: task.name,
      description: task.description,
      model: task.model,
      priority: task.priority
    });
  }
}
```

---

## 7. Sub-Agent Context Template

When spawning sub-agents, include this context:

```markdown
# Subagent Context

You are a **subagent** spawned by the main agent for a specific task.

## Your Role
- Complete the assigned ClawTrol task
- Call agent_complete when finished
- Don't initiate new conversations

## ClawTrol Task #XXX

Task ID: XXX
API Base: http://192.168.100.186:4001/api/v1
Token: YOUR_TOKEN

## Completion Instructions

When done, call:
\`\`\`bash
curl -X POST "http://192.168.100.186:4001/api/v1/tasks/XXX/agent_complete" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"output": "YOUR_SUMMARY_HERE", "status": "in_review"}'
\`\`\`

## Task Description

[Task description here]
```

---

## Troubleshooting

### Live transcript not showing

1. Check that `session_id` (not `session_key`) was linked
2. Verify the session file exists: `~/.openclaw/agents/main/sessions/{session_id}.jsonl`
3. Confirm the session is still active

### Model fallback not working

1. Check model status: `GET /models/status`
2. Clear expired limits: limits auto-expire, but you can force-clear
3. Verify fallback chain in user settings

### Task stuck in in_progress

1. Check for errors: `GET /tasks/:id` and look at `error_message`
2. Check session health: `GET /tasks/:id/session_health`
3. Consider handoff to different model: `POST /tasks/:id/handoff`

### Validation failing

1. Check validation_output for error details
2. Verify command works manually
3. Check timeout (60s max)

---

## Quick Reference

| Action | Endpoint |
|--------|----------|
| Create ready task | `POST /tasks/spawn_ready` |
| Link session | `POST /tasks/:id/link_session` |
| Complete task | `POST /tasks/:id/agent_complete` |
| Get transcript | `GET /tasks/:id/agent_log` |
| Check models | `GET /models/status` |
| Report limit | `POST /tasks/:id/report_rate_limit` |
| Handoff model | `POST /tasks/:id/handoff` |
| Start validation | `POST /tasks/:id/start_validation` |
| Run debate | `POST /tasks/:id/run_debate` |
