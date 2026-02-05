# 🦞 ClawTrol

**Open source mission control for your AI agents.**

ClawTrol is a kanban-style dashboard for managing AI coding agents. Track tasks, assign work to agents, monitor their activity in real-time, and collaborate asynchronously. Forked from [ClawDeck](https://github.com/clawdeckio/clawdeck) with extended agent integration features.

> 🚧 **Early Development** — ClawTrol is under active development. Expect breaking changes.

## Get Started

**Self-host (recommended)**  
Clone this repo and run your own instance. See [Self-Hosting](#self-hosting) below.

**Contribute**  
PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Features

### Core
- **Kanban Boards** — Organize tasks across multiple boards with tabs in navbar
- **Agent Assignment** — Assign tasks to your agent, track progress
- **Real-time Updates** — Hotwire-powered live UI with 15s auto-refresh
- **API Access** — Full REST API for agent integrations

### 🤖 Agent Integration
- **Live Activity View** — Watch agent work in real-time via `/api/v1/tasks/:id/agent_log`
- **Model Selection** — Choose model per task (opus, codex, gemini, glm, sonnet)
- **Session Tracking** — Link agent sessions with `agent_session_id` and `agent_session_key`
- **Spinner Indicator** — Visual indicator on cards with active agents

### 📊 Multi-Board System
- **Multiple Boards** — Create multiple boards per user (displayed as tabs)
- **Auto-Routing** — `spawn_ready` endpoint auto-detects project from task name
- **Board Context Menu** — Move tasks between boards easily

### 🔄 Model Rate Limiting
- **Model Status** — Check which models are available
- **Best Model Selection** — Automatically pick the best available model
- **Rate Limit Recording** — Track when models hit limits
- **Auto-Fallback** — Seamlessly switch to backup models when limited

### 🔗 Follow-up Tasks
- **Parent Linking** — Chain related tasks together
- **AI Suggestions** — Generate follow-up task suggestions with AI
- **Create Follow-ups** — One-click follow-up task creation

### ⏰ Scheduling
- **Nightly Tasks** — Delay execution until night hours
- **Recurring Tasks** — Templates for repeating work

### 🪝 Webhook Integration
- **OpenClaw Gateway** — Instant wake via webhook when tasks are assigned
- **Real-time Triggers** — No polling delay for agent activation

---

## How It Works

1. You create tasks and organize them on boards
2. You assign tasks to your agent (or use `spawn_ready` for auto-assignment)
3. Webhook notifies OpenClaw Gateway instantly (or agent polls for work)
4. Agent streams progress via the activity feed API
5. You watch everything in real-time with the terminal panel
6. Agent completes and optionally suggests follow-up tasks

---

## Tech Stack

- **Ruby** 3.3.1 / **Rails** 8.1
- **PostgreSQL** with Solid Queue, Cache, and Cable
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS**
- **Authentication** via GitHub OAuth or email/password

---

## Self-Hosting

### Prerequisites
- Ruby 3.3.1
- PostgreSQL
- Bundler

### Setup
```bash
git clone https://github.com/wolverin0/clawtrol.git
cd clawtrol
bundle install
bin/rails db:prepare
bin/dev
```

Visit `http://localhost:3000`

### Authentication Setup

ClawTrol supports two authentication methods:

1. **Email/Password** — Works out of the box
2. **GitHub OAuth** — Optional, recommended for production

#### GitHub OAuth Setup

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click **New OAuth App**
3. Fill in:
   - **Application name:** ClawTrol
   - **Homepage URL:** Your domain
   - **Authorization callback URL:** `https://yourdomain.com/auth/github/callback`
4. Add credentials to environment:

```bash
GITHUB_CLIENT_ID=your_client_id
GITHUB_CLIENT_SECRET=your_client_secret
```

### OpenClaw Integration

Configure webhook in Settings → OpenClaw Integration:
- **Gateway URL:** Your OpenClaw gateway endpoint
- **Gateway Token:** Your authentication token

### Running Tests
```bash
bin/rails test
bin/rails test:system
bin/rubocop
```

---

## API

ClawTrol exposes a REST API for agent integrations. Get your API token from Settings.

### Authentication

Include your token in every request:
```
Authorization: Bearer YOUR_TOKEN
```

Include agent identity headers:
```
X-Agent-Name: Otacon
X-Agent-Emoji: 📟
```

---

### Boards

```bash
# List boards
GET /api/v1/boards

# Get board
GET /api/v1/boards/:id

# Create board
POST /api/v1/boards
{ "name": "My Project", "icon": "🚀" }

# Update board
PATCH /api/v1/boards/:id

# Delete board
DELETE /api/v1/boards/:id
```

---

### Tasks

#### Standard CRUD

```bash
# List tasks (with filters)
GET /api/v1/tasks
GET /api/v1/tasks?board_id=1
GET /api/v1/tasks?status=in_progress
GET /api/v1/tasks?assigned=true    # Your work queue

# Get task
GET /api/v1/tasks/:id

# Create task
POST /api/v1/tasks
{ "name": "Research topic X", "status": "inbox", "board_id": 1 }

# Update task (with optional activity note)
PATCH /api/v1/tasks/:id
{ "status": "in_progress", "activity_note": "Starting work on this" }

# Delete task
DELETE /api/v1/tasks/:id

# Complete task
PATCH /api/v1/tasks/:id/complete

# Assign/unassign to agent
PATCH /api/v1/tasks/:id/assign
PATCH /api/v1/tasks/:id/unassign
```

#### Agent-Specific Endpoints

```bash
# Create task ready for agent (auto-routes to board based on name)
POST /api/v1/tasks/spawn_ready
{ "name": "ProjectName: Task title", "description": "...", "model": "opus" }

# Link agent session to task
POST /api/v1/tasks/:id/link_session
{ "agent_session_id": "uuid", "agent_session_key": "key" }

# Save agent output and complete
POST /api/v1/tasks/:id/agent_complete
{ "output": "Task completed successfully", "status": "in_review" }

# Get live agent activity log
GET /api/v1/tasks/:id/agent_log

# Check session health
GET /api/v1/tasks/:id/session_health
```

#### Follow-up Tasks

```bash
# Generate AI-suggested follow-up
POST /api/v1/tasks/:id/generate_followup

# Create follow-up task
POST /api/v1/tasks/:id/create_followup
{ "name": "Follow-up task name", "description": "..." }
```

---

### Models (Rate Limiting)

```bash
# Get all models status
GET /api/v1/models/status

# Get best available model
POST /api/v1/models/best
{ "preferred": "opus" }

# Record rate limit for a model
POST /api/v1/models/:name/limit
{ "duration_minutes": 60 }
```

---

### Recurring Tasks

```bash
# List recurring task templates
GET /api/v1/tasks/recurring
```

---

### Task Statuses
| Status | Description |
|--------|-------------|
| `inbox` | New, not prioritized |
| `up_next` | Ready to be assigned |
| `in_progress` | Being worked on |
| `in_review` | Done, needs human review |
| `done` | Complete |

### Priorities
`none`, `low`, `medium`, `high`

### Models
`opus`, `codex`, `gemini`, `glm`, `sonnet`

---

## UI Features

### Terminal Panel
- **Tabbed Interface** — Multiple agent sessions in tabs
- **Hover Preview** — Quick preview on card hover
- **Pin to Terminal** — Lock a task's output in view
- **Live Streaming** — Real-time agent activity updates

### Kanban Board
- **Auto-Refresh** — 15-second polling for updates
- **Spinner Indicator** — Shows active agent on card
- **Context Menu** — Right-click to move between boards
- **Board Tabs** — Quick navigation between projects

---

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Links

- 🐙 **GitHub:** [wolverin0/clawtrol](https://github.com/wolverin0/clawtrol)
- 🦞 **Upstream:** [clawdeckio/clawdeck](https://github.com/clawdeckio/clawdeck)

---

Built with 🦞 by the OpenClaw community.
