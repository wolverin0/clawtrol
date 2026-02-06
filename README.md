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
- **Real-time Updates** — WebSocket via ActionCable (KanbanChannel + AgentActivityChannel) with polling fallback
- **API Access** — Full REST API for agent integrations
- **Dashboard** — Overview page (`/dashboard`) with status cards, active agents, recent tasks, model status
- **Analytics** — Analytics page (`/analytics`) with CSS bar charts, period filtering (24h/7d/30d/all), model usage, board breakdown

### 🤖 Agent Integration
- **Live Activity View** — Watch agent work in real-time via WebSocket or `/api/v1/tasks/:id/agent_log`
- **Model Selection** — Choose model per task (opus, codex, gemini, glm, sonnet)
- **Auto Session Linking** — `agent_complete`, `claim`, and task create/update accept session params directly
- **Spinner Indicator** — Visual indicator on cards with active agents
- **Agent Terminal** — Full session transcript viewer with tabbed interface, hover preview, pin-to-terminal

### 📊 Multi-Board System
- **Multiple Boards** — Create multiple boards per user (displayed as tabs)
- **ALL Aggregator** — Read-only view across all boards
- **Auto-Routing** — `spawn_ready` endpoint auto-detects project from task name prefix
- **Board Context Menu** — Move tasks between boards easily
- **Archived Status** — Archive completed tasks to reduce board clutter

### ✅ Validation System
- **Validation Commands** — Run shell commands to validate agent output (exit 0 = pass)
- **Quick Templates** — One-click Rails Test, npm test, Rubocop, ESLint, pytest
- **Background Execution** — Validation runs async (up to 2 minutes)
- **Auto-Status** — Pass → `in_review`, Fail → stays `in_progress`
- **Command Sandboxing** — Shellwords + allowlist prevents injection attacks

### 🔄 Model Rate Limiting
- **Model Status** — Check which models are available
- **Best Model Selection** — Automatically pick the best available model
- **Rate Limit Recording** — Track when models hit limits
- **Auto-Fallback** — Seamlessly switch to backup models when limited

### 🔗 Follow-up Tasks
- **Parent Linking** — Chain related tasks together with visual parent links
- **AI Suggestions** — Generate follow-up task suggestions with AI
- **Create Follow-ups** — One-click follow-up creation with model/session inheritance
- **Auto-Done** — Parent auto-completes when follow-up is created

### 🔒 Task Dependencies
- **Blocking System** — Tasks can block other tasks with `blocked_by`
- **Circular Detection** — Prevents infinite dependency loops
- **🔒 Badge** — Blocked tasks show badge with blocker info
- **Drag Prevention** — Can't move blocked tasks to `in_progress`

### 🔔 Notifications
- **Bell Icon** — Notification center in navbar with unread count badge
- **Event Types** — Agent claimed, task completed, validation results
- **Browser Notifications** — Optional browser notification API integration
- **Mark All Read** — One-click clear all notifications

### ⌨️ Keyboard Shortcuts
- `n` — New task
- `Ctrl+/` — Toggle terminal
- `?` — Help modal with all shortcuts

### 📱 Mobile Responsive
- **Column Switcher** — Swipeable tab bar for kanban columns on mobile
- **Bottom Nav** — Fixed navigation (Dashboard/Board/Terminal/Settings)
- **Slide-in Panel** — Task modal slides from right on mobile, centered overlay on desktop

### 🎨 UI Polish
- **Card Progressive Disclosure** — Model-colored left borders (purple=Opus, green=Gemini, etc), hover badges
- **Undo Toast** — 5-second countdown on status changes with undo revert
- **Dark Theme** — WCAG-compliant contrast, column tints, done card dimming
- **File Viewer** — Browse agent output files in-modal with fullscreen expand + markdown rendering
- **Task Templates** — Slash commands in add-card: `/review`, `/bug`, `/doc`, `/test`, `/research`
- **Done Counter** — Today's completed tasks in header
- **Copy URL** — One-click copy task URL for sharing
- **Confetti** — Celebration animation on task completion 🎉

### ⏰ Scheduling
- **Nightly Tasks** — Delay execution until night hours
- **Recurring Tasks** — Daily/weekly/monthly templates with time picker

### 🪝 Webhook Integration
- **OpenClaw Gateway** — Instant wake via webhook when tasks are assigned
- **Real-time Triggers** — No polling delay for agent activation

### 🔐 Security
- **Command Injection Prevention** — Validation commands sandboxed with Shellwords + allowlist
- **API Token Hashing** — Tokens stored as SHA-256 hashes, never plaintext
- **AI Key Encryption** — `ai_api_key` encrypted at rest with Rails credentials
- **Settings Page** — Tabbed layout (Profile / Agent / AI / Integration)

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
- **ActionCable** — WebSocket for real-time kanban + agent activity
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS v4**
- **Propshaft** — Asset pipeline with importmap-rails
- **41 Stimulus Controllers** — Full client-side interactivity
- **Authentication** via GitHub OAuth or email/password
- **Docker Compose** — Production-ready setup with `install.sh`

---

## Self-Hosting

### Prerequisites
- Ruby 3.3.1
- PostgreSQL
- Bundler

### Option A: Docker Compose (recommended)
```bash
git clone https://github.com/wolverin0/clawtrol.git
cd clawtrol
chmod +x install.sh
./install.sh
```

Visit `http://localhost:4001`

### Option B: Manual Setup
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

## 🤖 AI-Assisted Installation

Have an AI assistant with shell access (OpenClaw, Claude Code, Codex)? Give it this prompt to install ClawTrol automatically:

---

**Copy this prompt to your AI assistant:**

> Install ClawTrol (AI agent mission control) for me:
>
> 1. Clone and install:
>    ```bash
>    cd ~ && git clone https://github.com/wolverin0/clawtrol.git clawdeck
>    cd clawdeck
>    chmod +x install.sh && ./install.sh
>    ```
>    If Docker isn't available, use manual setup:
>    ```bash
>    bundle install && bin/rails db:prepare && bin/dev
>    ```
>
> 2. Wait for server to start (port 4001 for Docker, 3000 for manual)
>
> 3. Create my user account via Rails console:
>    ```bash
>    bin/rails console
>    ```
>    ```ruby
>    User.create!(email: "MY_EMAIL", password: "MY_PASSWORD", name: "MY_NAME")
>    ```
>
> 4. Generate API token:
>    ```ruby
>    user = User.find_by(email: "MY_EMAIL")
>    token = user.api_tokens.create!(name: "Agent")
>    puts token.token  # Save this - only shown once
>    ```
>
> 5. Configure yourself to use ClawTrol:
>    - Add to your TOOLS.md: ClawTrol URL, API token, agent name/emoji
>    - Update HEARTBEAT.md to poll for assigned tasks
>    - Test: `curl -H "Authorization: Bearer TOKEN" http://localhost:4001/api/v1/tasks`
>
> 6. Confirm setup is complete and give me the dashboard URL.

---

**Replace before pasting:**
| Placeholder | Description |
|-------------|-------------|
| `MY_EMAIL` | Your login email |
| `MY_PASSWORD` | Secure password (12+ chars) |
| `MY_NAME` | Display name |

**Requirements:**
- Docker (recommended) or Ruby 3.3+ with PostgreSQL
- AI assistant with shell/exec access (OpenClaw, Claude Code, Codex CLI, etc.)

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
- **Live Streaming** — Real-time agent activity via WebSocket
- **Session Transcript** — Full conversation log with role icons and tool calls

### Kanban Board
- **WebSocket Updates** — Real-time via ActionCable (polling fallback)
- **Spinner Indicator** — Shows active agent on card
- **Context Menu** — Right-click to move between boards/statuses
- **Board Tabs** — Quick navigation between projects
- **Drag & Drop** — SortableJS with delete drop zone
- **Dependency Blocking** — 🔒 badge prevents moving blocked tasks

### Task Modal
- **Two-Column Layout** — Details left, agent activity + files right (desktop)
- **Auto-Save** — Debounced 500ms save on field changes
- **File Viewer** — Browse output files with syntax highlighting + fullscreen
- **Agent Activity** — Live session log with WebSocket updates
- **Priority Selector** — Visual fire icon buttons
- **Validation Output** — View command results inline

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
