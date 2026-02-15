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
- **Deep Research Mode** — Toggle multi-agent analysis for complex tasks
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
- **Telegram Push** — Get instant Telegram messages when tasks move to `in_review` or `done`
- **Webhook Push** — Generic webhook (JSON POST) for custom integrations (Slack, Discord, etc.)
- **Settings UI** — Configure Telegram bot token, chat ID, and webhook URL in Settings → Notifications tab
- **Test Button** — Send a test notification to verify your setup
- **Zero Dependencies** — Pure Rails, no external services required

#### Setting Up Telegram Notifications

1. Create a Telegram bot via [@BotFather](https://t.me/BotFather) and copy the token
2. Send `/start` to your bot, then get your chat ID from [@userinfobot](https://t.me/userinfobot)
3. Go to **Settings → Notifications** in ClawTrol
4. Paste your bot token and chat ID
5. Click **Test Notification** to verify
6. Done — you'll get a Telegram message every time a task completes

#### Webhook Integration

Set a webhook URL in Settings → Notifications. ClawTrol will POST JSON on task completion:

```json
{
  "event": "task_status_change",
  "task_id": 123,
  "task_name": "Fix login bug",
  "status": "in_review",
  "message": "📋 Task #123 → In review\n\nFix login bug\n\n...",
  "timestamp": "2026-02-13T14:30:00-03:00"
}
```

### ⌨️ Keyboard Shortcuts
- `n` — New task
- `Ctrl+/` — Toggle terminal
- `?` — Help modal with all shortcuts

### 📱 Mobile Responsive
- **Hamburger Menu** — Slide-out navigation panel (md:hidden) with all 11 nav links + Settings
- **Board Tabs as Dropdown** — `<select>` dropdown on mobile instead of horizontal scroll
- **Memory Panel** — Fixed positioning on mobile, absolute on desktop
- **Column Switcher** — Swipeable tab bar for kanban columns on mobile
- **Bottom Nav** — Fixed navigation (Dashboard/Board/Terminal/Settings)
- **Slide-in Panel** — Task modal slides from right on mobile, centered overlay on desktop

### 🎨 UI Polish
- **Card Progressive Disclosure** — Model-colored left borders (purple=Opus, green=Gemini, etc), hover badges
- **Undo Toast** — 5-second countdown on status changes with undo revert
- **Dark Theme** — WCAG-compliant contrast, column tints, done card dimming
- **File Viewer** — Browse agent output files in-modal with fullscreen expand + markdown rendering (`/view?file=path`)
- **Search** — Full-text search across all tasks with trigram indexing
- **Task Templates** — Slash commands in add-card: `/review`, `/bug`, `/doc`, `/test`, `/research`
- **Done Counter** — Today's completed tasks in header
- **Copy URL** — One-click copy task URL for sharing
- **Confetti** — Celebration animation on task completion 🎉

### ⏰ Scheduling
- **Nightly Tasks** — Delay execution until night hours
- **Recurring Tasks** — Daily/weekly/monthly templates with time picker

### 🌙 Nightshift Mission Control
- **19 Automated Missions** — Pre-configured nightly tasks: security scans, dependency updates, financial reports, network monitoring, email triage, tech news, RAG reindexing, and more
- **Mission Selector UI** — Terminal-themed `/nightshift` page with checkboxes, model indicators (Codex/Gemini/GLM), and estimated time per mission
- **ARM & Execute** — Select missions → click ARM → `NightshiftRunnerJob` executes them sequentially via OpenClaw wake
- **SolidQueue Recurring** — Automatic nightly run at 23:00 via `config/recurring.yml`
- **Engine Service** — `NightshiftEngineService` handles execution orchestration, completion callbacks, and timeout (30 min per mission)
- **Status Tracking** — Each selection tracks: `pending → running → completed/failed` with `launched_at` and `completed_at` timestamps
- **API Integration** — `GET /api/v1/nightshift/selections` + `PATCH` for agent status reporting
- **Completion Callbacks** — Agents report back via `PATCH /api/v1/nightshift/selections/:id` with result text
- **Evening Planning** — 21:00 cron sends day review + nightshift planner via Telegram

### 🔗 Link Inbox (Saved Links)
- **Save & Process URLs** — `/saved_links` page to save URLs for AI analysis
- **Gemini Processing** — One-click "Process with Gemini" button runs analysis via Gemini CLI (OAuth, no API key)
- **Batch Processing** — Process all pending links at once
- **Nightshift Integration** — Auto-process pending links during nightly runs
- **X/Twitter Support** — Uses fxtwitter API for tweet content extraction

### 🌙 Nightbeat Integration
- **Moon-Marked Tasks** — Nightly tasks are marked with a moon 🌙 icon
- **Nightbeat Filter** — Toggle to show/hide nightbeat tasks quickly
- **Morning Brief** — `/nightbeat` page shows overnight completed tasks grouped by project


### 🚀 Pipeline System (ClawRouter)
- **3-Layer Mechanical Pipeline** — Zero-token triage + context compilation + model routing
- **Triage (Layer 0)** — Ruby rules classify tasks into pipeline types: `quick-fix`, `bug-fix`, `feature`, `research`, `architecture`, `nightshift`
- **Context Compiler (Layer 1)** — Enriches tasks with project manifests, board context, dependencies, and optional RAG from Qdrant
- **Router (Layer 2)** — Selects optimal model based on task type, tier fallback chains (`free → subscription → api → expensive`)
- **Pipeline Stages** — `unstarted → triaged → context_ready → routed → executing → verifying → completed/failed`
- **Observation Mode** — Pipeline logs decisions without changing behavior (safe rollout)
- **Per-Board Activation** — Enable pipeline per board via API or Config Hub
- **Prompt Templates** — ERB templates per pipeline type with full context injection
- **Escalation** — Auto-bumps to higher model tier on repeated failures
- **YAML Config** — All rules, tiers, and templates configured in `config/pipelines.yml`

### 🐝 Swarm Launcher
- **Curated Task Ideas** — `/swarm` page with pre-configured task ideas organized by category
- **One-Click Launch** — Select ideas and launch them as real tasks on any board
- **Favorites** — Star frequently-used ideas for quick access
- **Board Routing** — Per-idea board assignment with dropdown override
- **Model Selection** — Per-idea model override with dropdown
- **Multi-Select** — Checkbox selection with "Select All" and batch launch
- **Launch History** — Track `times_launched` and `last_launched_at` per idea
- **Pipeline Integration** — Launched tasks auto-enter the pipeline with `pipeline_enabled: true`
- **Category Filters** — Filter ideas by category or favorites
- **Bottom Panel** — Shows selected count, estimated time, and launch button

### ⚙️ Config Hub
- **OpenClaw Configuration Dashboard** — `/config` page to manage all OpenClaw gateway settings from ClawTrol
- **15 Config Sections** — Typing, Identity, Sandbox, Compaction, Heartbeat, Session Reset, Message Queue, Media, Telegram, Discord, Logging, Channel, Gateway, Agent
- **Live Editing** — View and update OpenClaw configuration in real-time via gateway API
- **Gateway Health** — Status indicator showing gateway connection health
- **Log Viewer** — Tail OpenClaw logs directly from the Config Hub
- **Channel Management** — Configure per-channel behavior for messaging integrations

### 🏭 Agent Factory
- **Factory Loops** — Automated task generation cycles with play/pause/stop controls
- **Auto-Generate Personas** — Create board-specific agent personas automatically
- **Loop Metrics** — Track cycle completion rates, timing, and outcomes
- **API Control** — Full CRUD + play/pause/stop via REST API

### 🪝 Agent Complete Auto-Save Pipeline
- **Webhook Endpoint** — `POST /api/v1/hooks/agent_complete` for agent self-reporting
- **Accepted Payload** — `task_id`, `findings`, `session_id`, `session_key`, `output_files`
- **Auto Output Save** — Persists findings into task description under `## Agent Output`
- **Auto Review Handoff** — Moves task to `in_review` automatically
- **Session + File Linking** — Links session metadata and extracts output files from commits/transcripts
- **Token Auth** — Requires `X-Hook-Token` header

### 🔒 Done Validation
- **Agent Output Required** — Agent-assigned tasks cannot move to `done` without `## Agent Output`
- **Clear API Error** — Returns HTTP `422` with actionable validation message
- **Kanban Guardrails** — Drag/drop reverts card and shows toast on rejection

### 📄 Transcript Recovery
- **Recover Endpoint** — `POST /api/v1/tasks/:id/recover_output`
- **UI Recovery Actions** — Buttons: **"Recuperar del Transcript"** and **"Escribir manualmente"**
- **Smart Extraction** — Reads `.jsonl` transcript and restores latest assistant summary

### 📁 Output Files Auto-Extraction
- **Findings Parsing** — Detects file paths directly from findings text
- **Transcript Commit Mining** — Extracts changed files from git commits in transcript
- **Merge + Dedupe** — Combines all discovered files and removes duplicates

### 🛰️ Agent Activity Improvements
- **Session Fallbacks** — Shows activity even without `session_id` using description markers
- **Lifecycle Timeline** — `assigned → claimed → output posted → current status`
- **Transcript Access** — Shows transcript link when transcript file exists

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
5. Agent finishes and calls `POST /api/v1/hooks/agent_complete`
6. ClawTrol auto-saves findings to `## Agent Output`, links session/files, and moves task to `in_review`
7. Done validation enforces output presence before allowing move to `done`
8. You review in terminal/modal and optionally create follow-up tasks

## Agent Install Prompt (OpenClaw / Telegram Orchestrator)

ClawTrol works best when your orchestrator has an explicit "tooling + reporting contract" prompt so it:

- knows which endpoints exist and how to authenticate
- always reports back deterministically at the end of each run
- can requeue the same task for follow-ups (no kanban bloat)

In your running instance, open `http://<host>:<port>/settings` → `Integration` and use **Agent Install Prompt**.

If you're integrating manually:

- API endpoints live under `/api/v1/*` (Bearer token)
- Completion hooks live under `/api/v1/hooks/*` (`X-Hook-Token`)
- Follow-up is signaled via `POST /api/v1/hooks/task_outcome` with `recommended_action="requeue_same_task"`

---

## Tech Stack

- **Ruby** 3.3.1 / **Rails** 8.1
- **PostgreSQL** with Solid Queue, Cache, and Cable
- **Solid Queue** — Background jobs for validation, async processing, and webhook-driven workflows
- **ActionCable** — WebSocket for real-time kanban + agent activity
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS v4**
- **Propshaft** — Asset pipeline with importmap-rails
- **45+ Stimulus Controllers** — Full client-side interactivity
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

## 🤖 AI-Assisted Installation & Onboarding

Have an AI assistant with shell access (OpenClaw, Claude Code, Codex)? Give it the prompt below to install ClawTrol **and** fully configure itself as your agent — API tokens, webhook hooks, heartbeat polling, and auto-runner included.

---

### One-Prompt Install

**Copy this entire prompt to your AI assistant:**

> Install and configure ClawTrol (AI agent mission control) for me. Do ALL steps — don't stop until you've verified everything works.
>
> **Step 1 — Clone & Install**
> ```bash
> cd ~ && git clone https://github.com/wolverin0/clawtrol.git clawdeck
> cd clawdeck
> chmod +x install.sh && ./install.sh
> ```
> If Docker isn't available, fall back to manual:
> ```bash
> bundle install && bin/rails db:prepare && bin/dev
> ```
>
> **Step 2 — Wait for server**
> - Docker: port 4001
> - Manual: port 3000
> - Health check: `curl -sf http://localhost:PORT/up` (retry up to 30s)
>
> **Step 3 — Create user account**
> ```bash
> cd ~/clawdeck && bin/rails runner "
>   User.create!(
>     email: 'MY_EMAIL',
>     password: 'MY_PASSWORD',
>     name: 'MY_NAME'
>   )
>   puts '✅ User created'
> "
> ```
>
> **Step 4 — Generate API token + Hooks token**
> ```bash
> cd ~/clawdeck && bin/rails runner "
>   user = User.find_by!(email: 'MY_EMAIL')
>   api_token = user.api_tokens.create!(name: 'Agent')
>   puts 'API_TOKEN=' + api_token.token
>   puts 'HOOKS_TOKEN=' + Rails.application.config.hooks_token.to_s
> "
> ```
> Save both tokens — the API token is only shown once.
>
> **Step 5 — Create a default board**
> ```bash
> curl -s -X POST http://localhost:PORT/api/v1/boards \
>   -H "Authorization: Bearer API_TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"name": "Main", "icon": "🚀"}' | jq .
> ```
>
> **Step 6 — Configure yourself as the ClawTrol agent**
>
> Add these to your workspace TOOLS.md (or equivalent config):
> ```
> ### ClawTrol (Task Dashboard / Mission Control)
> | Key | Value |
> |-----|-------|
> | URL | http://HOST:PORT |
> | API Token | API_TOKEN |
> | Hooks Token | HOOKS_TOKEN |
> | Agent Name | YOUR_AGENT_NAME |
> | Agent Emoji | YOUR_EMOJI |
> ```
>
> Add these env vars (e.g., `~/.openclaw/.env` or your agent's env):
> ```bash
> CLAWTROL_API_TOKEN=API_TOKEN
> CLAWTROL_HOOKS_TOKEN=HOOKS_TOKEN
APP_BASE_URL=http://HOST:PORT  # Used for webhook callbacks and links
> ```
>
> **Step 7 — Set up heartbeat polling**
>
> Add to your HEARTBEAT.md (or equivalent periodic check):
> ```markdown
> ### ClawTrol Tasks
> # Health check first
> curl -sf http://HOST:PORT/up >/dev/null 2>&1 || echo "⚠️ ClawTrol DOWN"
>
> # Poll for assigned tasks
> source ~/.openclaw/.env  # or wherever your env is
> curl -s -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
>   http://HOST:PORT/api/v1/tasks?assigned=true&status=up_next
> ```
>
> **Step 8 — Set up the completion contract**
>
> After EVERY task you complete, fire these two hooks IN ORDER:
>
> Hook 1 — `task_outcome` (structured result):
> ```bash
> curl -s -X POST http://HOST:PORT/api/v1/hooks/task_outcome \
>   -H "X-Hook-Token: $CLAWTROL_HOOKS_TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "version": "1",
>     "task_id": TASK_ID,
>     "run_id": "SESSION_UUID",
>     "ended_at": "ISO8601_TIMESTAMP",
>     "needs_follow_up": false,
>     "recommended_action": "in_review",
>     "summary": "What was accomplished",
>     "achieved": ["item 1", "item 2"],
>     "evidence": ["proof 1"],
>     "remaining": []
>   }'
> ```
>
> Hook 2 — `agent_complete` (saves output + transitions status):
> ```bash
> curl -s -X POST http://HOST:PORT/api/v1/hooks/agent_complete \
>   -H "X-Hook-Token: $CLAWTROL_HOOKS_TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{
>     "task_id": TASK_ID,
>     "session_id": "SESSION_UUID",
>     "findings": "Detailed summary of work done",
>     "output_files": ["file1.rb", "file2.js"]
>   }'
> ```
>
> **Step 9 — Verify the full loop**
>
> Create a test task, execute it, fire both hooks, confirm it reaches `done` (or `in_review`):
> ```bash
> # Create
> TASK=$(curl -s -X POST http://HOST:PORT/api/v1/tasks \
>   -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"name":"Test: onboarding verification","board_id":BOARD_ID,"status":"up_next","tags":["test","quick-fix"],"assigned_to_agent":true}')
> TASK_ID=$(echo $TASK | jq -r .id)
>
> # Move to in_progress
> curl -s -X PATCH http://HOST:PORT/api/v1/tasks/$TASK_ID \
>   -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
>   -H "Content-Type: application/json" \
>   -d '{"status":"in_progress"}'
>
> # Fire hooks (use a random UUID as run_id)
> # ... (fire task_outcome + agent_complete as above)
>
> # Verify final status
> curl -s -H "Authorization: Bearer $CLAWTROL_API_TOKEN" \
>   http://HOST:PORT/api/v1/tasks/$TASK_ID | jq .status
> # Should be "done" (auto-review: quick-fix + output) or "in_review"
> ```
>
> **Step 10 — Report to me**
>
> Tell me:
> - ✅ Dashboard URL
> - ✅ Board created
> - ✅ API + Hooks tokens saved
> - ✅ Heartbeat configured
> - ✅ Completion hooks tested
> - ✅ Test task verified end-to-end

---

**Replace before pasting:**

| Placeholder | Description |
|-------------|-------------|
| `MY_EMAIL` | Your login email |
| `MY_PASSWORD` | Secure password (12+ chars) |
| `MY_NAME` | Display name |
| `HOST:PORT` | Your server address (e.g., `localhost:4001`) |
| `YOUR_AGENT_NAME` | What your agent calls itself |
| `YOUR_EMOJI` | Agent's signature emoji |
| `BOARD_ID` | Board ID from Step 5 (usually `1`) |

**Requirements:**
- Docker (recommended) or Ruby 3.3+ with PostgreSQL
- AI assistant with shell/exec access (OpenClaw, Claude Code, Codex CLI, etc.)
- 5 minutes

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

# Save agent output and complete (legacy/manual path)
POST /api/v1/tasks/:id/agent_complete
{ "output": "Task completed successfully", "status": "in_review" }

# Recover missing output from transcript (.jsonl)
POST /api/v1/tasks/:id/recover_output

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

### Webhook: Agent Complete (Auto-Save Pipeline)

`POST /api/v1/hooks/agent_complete`

Primary endpoint for autonomous agents to self-report completion and persist output. This is the recommended integration path for production agents.

**Authentication**

Send webhook token in header:

```
X-Hook-Token: YOUR_HOOKS_TOKEN
```

**Request Body (JSON)**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | integer | ✅ | Target task ID to update |
| `findings` | string | ✅ | Work summary; stored under `## Agent Output` |
| `session_id` | string | optional | Agent session UUID for transcript/activity linking |
| `session_key` | string | optional | Session key used by terminal/transcript viewer |
| `output_files` | array[string] | optional | Explicit output file list (merged with auto-extracted files) |

**Example Request**

```bash
curl -s -X POST http://YOUR_HOST:4001/api/v1/hooks/agent_complete \
  -H "X-Hook-Token: YOUR_HOOKS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": 302,
    "findings": "Implemented feature X and updated docs.",
    "session_id": "sess_123",
    "session_key": "agent:main:subagent:abc",
    "output_files": ["README.md", "app/controllers/tasks_controller.rb"]
  }'
```

**Behavior**

- Auto-appends/updates `## Agent Output` in task description
- Auto-transitions task status to `in_review`
- Links session metadata when provided
- Auto-extracts output files from findings text and transcript commit data
- Merges + deduplicates discovered files and provided `output_files`

**Success Response**

- `200 OK` with updated task payload

**Error Responses**

- `401 Unauthorized` — missing/invalid `X-Hook-Token`
- `404 Not Found` — task not found
- `422 Unprocessable Entity` — invalid payload (e.g., missing required fields)

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

### Nightshift

```bash
# List tonight's mission selections
GET /api/v1/nightshift/selections

# Update mission status (for agents reporting back)
PATCH /api/v1/nightshift/selections/:id
{ "status": "completed", "result": "All checks passed" }

# List all available missions
GET /api/v1/nightshift/tasks

# Launch selected missions
POST /api/v1/nightshift/launch
{ "task_ids": [1, 3, 5] }
```

### Saved Links

```bash
# List saved links
GET /api/v1/saved_links

# Create saved link
POST /api/v1/saved_links
{ "url": "https://github.com/example/repo", "title": "Example Repo" }

# Update saved link
PATCH /api/v1/saved_links/:id

# Get pending links
GET /api/v1/saved_links/pending
```


### Swarm Ideas

```bash
# List swarm ideas
GET /api/v1/swarm_ideas

# Create swarm idea
POST /api/v1/swarm_ideas
{ "swarm_idea": { "title": "Fix auth bugs", "description": "...", "category": "bug-fix", "suggested_model": "codex" } }

# Update swarm idea
PATCH /api/v1/swarm_ideas/:id

# Delete swarm idea
DELETE /api/v1/swarm_ideas/:id

# Launch idea as task
POST /api/v1/swarm_ideas/:id/launch
{ "board_id": 1, "model": "codex" }
```

### Pipeline

```bash
# Pipeline status overview
GET /api/v1/pipeline/status

# Enable pipeline on a board
POST /api/v1/pipeline/enable_board/:board_id

# Disable pipeline on a board
POST /api/v1/pipeline/disable_board/:board_id

# Get pipeline log for a task
GET /api/v1/pipeline/task/:id/log

# Reprocess a task through the pipeline
POST /api/v1/pipeline/reprocess/:id

# Route a specific task through pipeline
POST /api/v1/tasks/:id/route_pipeline

# Get pipeline info for a task
GET /api/v1/tasks/:id/pipeline_info
```

### Agent Personas

```bash
# List agent personas
GET /api/v1/agent_personas

# Create persona
POST /api/v1/agent_personas
{ "name": "Security Bot", "board_id": 1, "model": "codex" }

# Import personas
POST /api/v1/agent_personas/import

# Update persona
PATCH /api/v1/agent_personas/:id

# Delete persona
DELETE /api/v1/agent_personas/:id
```

### Factory Loops

```bash
# List factory loops
GET /api/v1/factory/loops

# Create factory loop
POST /api/v1/factory/loops
{ "name": "Nightly bugs", "board_id": 1 }

# Control loop
POST /api/v1/factory/loops/:id/play
POST /api/v1/factory/loops/:id/pause
POST /api/v1/factory/loops/:id/stop

# Loop metrics
GET /api/v1/factory/loops/:id/metrics

# Complete a factory cycle
POST /api/v1/factory/cycles/:id/complete
```

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

### Pipeline Stages
`unstarted`, `triaged`, `context_ready`, `routed`, `executing`, `verifying`, `completed`, `failed`

### Priorities
`none`, `low`, `medium`, `high`

### Models
`opus`, `codex`, `gemini`, `glm`, `sonnet`, `flash`

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

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/). A git hook validates your commit messages automatically.

**Format:** `<type>[optional scope]: <description>`

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `style`, `perf`, `build`

**Setup the hook:**
```bash
ln -sf ../../bin/commit-msg-hook .git/hooks/commit-msg
```

**Generate changelog:**
```bash
bin/changelog
```

The changelog is also auto-generated on pushes to `main` via GitHub Actions.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Links

- 🐙 **GitHub:** [wolverin0/clawtrol](https://github.com/wolverin0/clawtrol)
- 🦞 **Upstream:** [clawdeckio/clawdeck](https://github.com/clawdeckio/clawdeck)

## Telegram Notification Routing

Tasks can route completion notifications back to the originating Telegram topic:

- **`origin_chat_id`** (string) — the Telegram chat/group ID the task was created from
- **`origin_thread_id`** (integer) — the topic/thread ID within that group

### Setup

1. Set `CLAWTROL_TELEGRAM_BOT_TOKEN` env var with your Telegram bot token
2. When creating tasks via the API, pass `origin_chat_id` and optionally `origin_thread_id`:

```bash
curl -X POST http://localhost:4001/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task": {"name": "Fix bug", "origin_chat_id": "-100123456789", "origin_thread_id": 42}}'
```

3. When the task reaches `in_review` or `done`, a notification is sent to that chat/topic automatically
4. If no `origin_chat_id` is set, Telegram notification is silently skipped
5. Webhook notifications (via `webhook_notification_url` on User) still work as a secondary mechanism

---

Built with 🦞 by the OpenClaw community.
