# Agent Integration Spec

ClawDeck is designed as a **personal mission control for your AI agent**. This document specifies how an OpenClaw agent (or any compatible agent) integrates with ClawDeck.

---

## Philosophy

This isn't a generic kanban. It's **your window into what your agent is doing**.

The board should feel like:
- Checking in on a coworker
- Seeing their desk, their tasks, their status
- A two-way communication channel

The agent's personality is part of the product. Names, avatars, emoji — all visible throughout.

---

## Authentication

### API Token (Simple & Recommended)

- User creates an API token in ClawDeck settings
- Agent stores token in its config
- All API calls use: `Authorization: Bearer <token>`

```bash
curl -H "Authorization: Bearer cd_xxxxxxxxxxxx" \
  https://your-clawdeck.com/api/v1/tasks
```

No OAuth complexity. Self-hosted, single-user — keep it simple.

---

## Agent Workflow

```
┌─────────────┐      poll/webhook     ┌─────────────┐
│  ClawDeck   │◄────────────────────►│  OpenClaw   │
│  (Board)    │       API calls       │  (Agent)    │
└─────────────┘                       └─────────────┘
```

### Task Lifecycle (from agent perspective)

1. **Discover work** — Poll or receive webhook for tasks with `status=up_next`
2. **Claim task** — Move first available task to `in_progress`
3. **Work on it** — Add comments for progress updates
4. **Get stuck?** — Set `blocked=true`, add comment explaining why
5. **Finish** — Move to `in_review`, add summary comment
6. **Human reviews** — User moves to `done` (or back for revisions)

### Auto-Assign Behavior

- Agent automatically picks the **first task** in `up_next` (by position)
- Tasks are processed in order — drag to reprioritize
- Only one task `in_progress` at a time (unless configured otherwise)

---

## API Endpoints

### Get Work Queue

```http
GET /api/v1/tasks?status=up_next
```

Returns tasks ready for the agent to pick up, ordered by position.

### Claim a Task

```http
PATCH /api/v1/tasks/:id
Content-Type: application/json

{
  "task": {
    "status": "in_progress"
  }
}
```

### Add Progress Comment

```http
POST /api/v1/tasks/:id/comments
Content-Type: application/json

{
  "comment": {
    "author_type": "agent",
    "author_name": "Maxie",
    "body": "Working on this now! Found the issue in the auth flow. 🔧"
  }
}
```

### Check for Comments Needing Reply

Poll for tasks where a user has commented and the agent hasn't replied yet:

```http
GET /api/v1/tasks?needs_reply=true
```

This returns tasks where `needs_agent_reply=true`. The flag is automatically:
- Set to `true` when a user adds a comment
- Set to `false` when the agent adds a comment

**Recommended polling pattern:**
1. Check `?needs_reply=true` on each heartbeat
2. For each task returned, read the latest comment
3. Reply to that specific task (not any other task!)
4. Your reply automatically clears the `needs_agent_reply` flag

### Mark as Blocked

```http
PATCH /api/v1/tasks/:id
Content-Type: application/json

{
  "task": {
    "blocked": true
  }
}
```

Always add a comment explaining why:

```http
POST /api/v1/tasks/:id/comments
Content-Type: application/json

{
  "comment": {
    "author_type": "agent",
    "author_name": "Maxie",
    "body": "🚫 Blocked: I need the API credentials to continue. Can you add them to the .env file?"
  }
}
```

### Submit for Review

```http
PATCH /api/v1/tasks/:id
Content-Type: application/json

{
  "task": {
    "status": "in_review",
    "blocked": false
  }
}
```

### Create a Task (Agent-Initiated)

```http
POST /api/v1/tasks
Content-Type: application/json

{
  "task": {
    "name": "Refactor auth module",
    "description": "Found some tech debt while working on login",
    "status": "inbox",
    "tags": ["tech-debt", "auth"]
  }
}
```

---

## Polling vs Webhooks

### Polling (Always Available)

Agent periodically checks for new tasks:

```
Every 5 minutes (or on heartbeat):
  GET /api/v1/tasks?status=up_next
  If tasks exist and auto_pickup enabled:
    Claim first task
```

### Webhooks (Real-Time, Optional)

ClawDeck can notify the agent instantly when:
- Task moved to `up_next`
- Comment added to agent's `in_progress` task
- Task unblocked

Webhook payload:
```json
{
  "event": "task.ready",
  "task_id": 123,
  "task_name": "Fix login bug",
  "timestamp": "2026-01-30T16:00:00Z"
}
```

**Recommendation:** Implement both. Polling as reliable fallback, webhooks for speed.

---

## UI: Agent Controls

### Header Bar

```
┌──────────────────────────────────────────────────────────────┐
│ 🦊 Maxie                              [● Auto] [○ Pause]     │
│ Currently working on: Fix login bug                          │
├──────────────────────────────────────────────────────────────┤
│ Inbox │ Up Next │ In Progress │ In Review │ Done             │
└──────────────────────────────────────────────────────────────┘
```

**Elements:**
- **Agent identity:** Emoji + name (e.g., `🦊 Maxie`)
- **Status:** What they're working on (or "Idle")
- **Auto/Pause toggle:**
  - **Auto:** Agent picks up `up_next` tasks automatically
  - **Pause:** Agent finishes current task but doesn't pick new ones

### Task Cards

When agent is working on a task:
```
┌─────────────────────────────┐
│ Fix login bug               │
│ #auth #urgent               │
│ 🦊 In progress · 2 comments │
└─────────────────────────────┘
```

When blocked:
```
┌─────────────────────────────┐
│ 🚫 Fix login bug            │  ← Red border or indicator
│ #auth #urgent               │
│ 🦊 Blocked · Needs input    │
└─────────────────────────────┘
```

### Comments Thread

```
┌─────────────────────────────────────┐
│ 🦊 Maxie · 2 min ago                │
│ Working on this now! Found the      │
│ issue in the auth flow. 🔧          │
├─────────────────────────────────────┤
│ 👤 Max · 5 min ago                  │
│ Can you check the login page?       │
└─────────────────────────────────────┘
```

- Agent comments: Show emoji + name, personality allowed
- User comments: Show avatar or generic user icon

---

## OpenClaw Configuration

```yaml
# clawdeck.yaml or in main config
clawdeck:
  enabled: true
  url: "https://your-clawdeck.example.com"
  api_token: "cd_xxxxxxxxxxxx"
  
  agent:
    name: "Maxie"
    emoji: "🦊"
  
  behavior:
    auto_pickup: true      # Pick up tasks automatically
    poll_interval: 300     # Seconds between polls (0 = heartbeat only)
    max_concurrent: 1      # Tasks in progress at once
  
  webhook:
    enabled: true
    endpoint: "/webhooks/clawdeck"  # Where ClawDeck sends events
```

---

## Task Statuses

| Status | Meaning | Who moves it here |
|--------|---------|-------------------|
| `inbox` | Ideas, backlog — agent sees but ignores | User |
| `up_next` | Ready for agent to pick up | User |
| `in_progress` | Agent is actively working | Agent (auto) |
| `in_review` | Agent finished, needs human review | Agent |
| `done` | Approved and complete | User |

---

## Tags

- Free-form, user-created
- Displayed as pills on task cards
- Filterable in sidebar
- Agent can add tags when creating tasks

Examples: `#urgent`, `#bug`, `#feature`, `#research`, `#maxie`

---

## Blocked State

A task can be `blocked` in any status (usually `in_progress`).

**When blocked:**
- Red visual indicator on card
- Agent adds comment explaining why
- User gets notified (if webhooks configured)
- Agent waits for user to respond/unblock

**Unblocking:**
- User responds in comments
- User sets `blocked: false`
- Agent continues work

---

## Future Considerations

- **Multiple agents:** Support for multiple OpenClaw agents (separate boards or shared)
- **Agent capabilities:** What can this agent do? (code, research, email, etc.)
- **Estimated time:** Agent provides time estimates for tasks
- **Recurring tasks:** Tasks that reset to `up_next` on schedule

---

## Summary

ClawDeck + OpenClaw = a visual mission control for your AI agent.

- You queue work in `Up Next`
- Agent picks it up automatically
- You see progress in real-time
- Comments for back-and-forth
- Blocked state when agent needs help
- Review before marking done

Simple. Visual. Personal. 🦊
