# ClawTrol Strategic Roadmap

**Date:** February 5, 2026  
**Author:** AI Strategic Analysis (Task #122)  
**Project:** ClawTrol (née ClawDeck) — Mission Control for AI Agents  
**Stack:** Ruby on Rails 8.1, PostgreSQL, Tailwind CSS 4, Stimulus.js, Turbo

---

## Executive Summary

ClawTrol is a kanban-style dashboard purpose-built for orchestrating AI coding agents. After reviewing the entire codebase (~200 files, 35 Stimulus controllers, 7 models, full REST API), this document provides a comprehensive strategic plan covering UX/UI improvements, feature recommendations, OpenClaw integration design, onboarding vision, and competitive positioning.

**The core insight:** ClawTrol's superpower is not being "yet another kanban board" — it's being the **visual nervous system** between a human orchestrator and their fleet of AI agents. Every decision in this roadmap should amplify that unique position.

---

## Table of Contents

1. [UX/UI Improvements](#1-uxui-improvements)
2. [Feature Recommendations (Ranked)](#2-feature-recommendations-ranked)
3. [OpenClaw Integration — Seamless Onboarding](#3-openclaw-integration--seamless-onboarding)
4. [The "10-Minute Setup" Vision](#4-the-10-minute-setup-vision)
5. [Competitive Analysis](#5-competitive-analysis)
6. [Implementation Priorities](#6-implementation-priorities)

---

## 1. UX/UI Improvements

### 1.1 What's Currently Clunky

After analyzing every view template, controller, and Stimulus controller, these are the friction points:

#### A. Information Density Overload on Task Cards

The `_task_card.html.erb` partial is **~280 lines** of ERB. Each card can show: task ID, name, spinner, error banner, priority flames, NEXT button, follow-up button, board badge, model badge, review status badge, validation badge, recurring icon, nightly icon, follow-up icon, agent emoji, and the 📟 agent activity button — all in a card that's ~240px wide.

**Problem:** Cards are visually noisy. When you have 20 tasks across 5 columns, the cognitive load is enormous.

**Recommendation:**
- **Progressive disclosure**: Show only title, ID, and priority by default. Reveal model/review/validation badges on hover (desktop) or tap (mobile)
- **Badge consolidation**: Combine recurring + nightly + model into a single "metadata row" that collapses
- **Status-aware simplification**: Inbox cards don't need NEXT/follow-up/review badges. Show those only when the task reaches a relevant status
- **Color-coded left border**: Currently only used for blocked/error. Use it to encode model (purple=opus, blue=sonnet, green=gemini, etc.) — one visual cue instead of a text badge

#### B. Settings Page is a Scroll Marathon

`profiles/show.html.erb` is a **single long page** with 5 separate forms: Profile, AI Settings, Session Continuation, Error Handling, and OpenClaw Integration. Each has its own save button. Users must scroll ~1500px to configure everything.

**Recommendation:**
- **Tabbed settings page** with sections: Profile | Agent | AI | Integration
- Each tab loads its content via Turbo Frame (keeps URLs bookmarkable)
- Add a settings sidebar on desktop with quick-jump links
- Move "Copy agent prompt" to a prominent first-time wizard (see Section 3)

#### C. Context Menu is Desktop-Only Discovery

The right-click context menu (`dropdown_controller.js`) is powerful but invisible. New users don't know it exists. On mobile, it's triggered by long-press, which conflicts with text selection.

**Recommendation:**
- Add a visible "⋯" menu button to each card (top-right corner, visible on hover/tap)
- On mobile, make the ⋯ button always visible
- Add keyboard shortcuts for power users: `n` = new task, `a` = assign to agent, `→` = move to next status
- Show a one-time tooltip: "Right-click cards for actions" on first board visit

#### D. Task Modal — Desktop Layout is Excellent, Mobile Falls Short

The `_panel.html.erb` dual-column modal is well-designed on desktop (task details left, agent activity right). But on mobile:
- The description text area has `max-h-48` — too short for detailed task specs
- Agent activity is below the fold (users must scroll past form fields)
- No way to view file outputs without scrolling back up
- Auto-save fires on every keystroke (via `scheduleAutoSave`), which can cause jank on slow networks

**Recommendation:**
- **Mobile tabs** inside the modal: "Details" | "Agent" | "Files" (instead of stacking vertically)
- Make description expandable (click to expand, not fixed max-height)
- Debounce auto-save to 1.5s (currently relies on Stimulus scheduling, but the UX feels laggy)
- Add a "full-screen" button on mobile to take over the whole viewport

#### E. Board Header Could Be a Dashboard

The header shows: brand, task counts (inbox + in_progress), board settings, model status, error badge, agent indicator, and user avatar. But it's missing the most important at-a-glance info.

**Recommendation — Mini Dashboard Strip:**
```
🦞 ClawTrol    📥 3 inbox  |  🔄 2 active  |  👀 1 review  |  ✅ 12 done today    📟 Otacon ● online
```
- Show **all** column counts, not just inbox + in_progress
- Add "done today" counter (dopamine hit for the user)
- Show agent name + online status more prominently
- On mobile: collapse to icon-only, expand on tap

### 1.2 Making the Kanban More Intuitive

#### A. Column Visual Hierarchy

Currently all 5 columns look identical (same bg, same border, same width). The user's eye has no anchor.

**Recommendation:**
- **In Progress** column gets a subtle accent border-top (this is where the action is)
- **Done** column gets a slightly dimmed background (completed work fades)
- Column widths: Make "In Progress" and "In Review" slightly wider (they contain the most actionable info)
- Add column-specific empty states: "Inbox empty — drag tasks here or create via API" / "Nothing in review — your agents are still working"

#### B. Agent Presence Indicators

When an agent is actively working on a task, the only visual signal is a tiny spinner next to the task name. This is easy to miss.

**Recommendation:**
- **Pulsing glow** on the entire card when agent is actively writing (detected via `agent_claimed_at` being recent)
- **Progress bar** at the bottom of the card showing estimated completion (based on context_usage_percent)
- **"Agent typing..."** indicator in the terminal panel (similar to chat apps)
- **Sound notification** option when agent completes a task (opt-in in settings)

#### C. Drag-and-Drop Refinements

The SortableJS integration works but has UX gaps:
- No visual indicator of where the card will land
- The delete drop zone appears at the bottom — easy to accidentally trigger on mobile
- No undo for drag operations

**Recommendation:**
- Add a **drop indicator line** between cards (blue horizontal line where the card will insert)
- Move delete to swipe-left gesture on mobile (not drag-to-bottom)
- Add **undo toast** after any status change: "Moved to In Review — Undo?" (5-second timer)
- Disable drag for `in_review` and `done` columns (they auto-sort by date — dragging reorders but the page refresh reverts, confusing users)

### 1.3 Mobile Experience Improvements

ClawTrol is PWA-capable (has manifest.json, service worker, mobile meta tags) but the mobile experience is fundamentally a shrunken desktop:

#### Current Issues:
- Columns are horizontally scrollable at 288px width — requires lots of swiping
- The agent terminal panel floats at bottom and overlaps content
- Board tabs overflow with >3 boards
- No offline capability despite service worker registration

#### Recommendations:

1. **Single-Column Mobile View**: Instead of horizontal scroll, show one column at a time with a tab bar: `Inbox | Next | Active | Review | Done`. Swipe left/right to switch columns.

2. **Bottom Navigation Bar**: Replace the header board tabs with a persistent bottom nav on mobile:
   ```
   [ 📋 Board ] [ 📟 Agent ] [ ⚙️ Settings ] [ ➕ New Task ]
   ```

3. **Pull-to-Refresh**: Replace the 15s polling with pull-to-refresh on mobile (more battery friendly, more intuitive)

4. **Floating Action Button**: Add a FAB for "New Task" — the inline-add at the bottom of each column is hard to reach on mobile

5. **Haptic Feedback**: On supported browsers, add subtle haptic feedback on drag-drop and status changes

### 1.4 Dashboard / Overview Page

Currently there's no overview page — users land directly on their last board. For a user managing 5+ agents across multiple boards, a dashboard is essential.

#### Proposed Dashboard Layout:

```
┌──────────────────────────────────────────────────────────┐
│  🦞 ClawTrol Dashboard                    📟 Otacon ●    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │ 📥 Inbox    │ │ 🔄 Active   │ │ ⚠️ Errors   │       │
│  │    7        │ │    3        │ │    1         │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 🔴 LIVE: Agent Activity                           │   │
│  │ Task #103 "Fix auth bug" — opus — 67% context     │   │
│  │ Task #104 "Add dark mode" — sonnet — 23% context  │   │
│  │ Task #105 "Write tests" — codex — 12% context     │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 📊 Today's Activity                               │   │
│  │ ✅ 5 completed  •  🚀 8 spawned  •  ⚠️ 1 failed  │   │
│  │ ████████████░░░░ 62% throughput                    │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 🤖 Model Status                                   │   │
│  │ opus ●  sonnet ●  codex ○ (resets 14:30)          │   │
│  │ gemini ●  glm ●                                   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  Recent Tasks (across all boards)                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │ #103 Fix auth bug          🔄 In Progress  opus   │ │
│  │ #102 Update README         ✅ Done          sonnet │ │
│  │ #101 Research competitors  👀 In Review     gemini │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

**Implementation:** Add a `DashboardController` at `/dashboard` that aggregates data across all boards. Use the existing aggregator board concept but with a dedicated view.

### 1.5 Agent Work Visualization

The agent terminal panel (`_agent_terminal.html.erb`) is ClawTrol's killer feature — a retro-styled terminal showing live agent output. But it could be much better:

#### Current State:
- Green-on-black terminal with CRT scanline effect
- Shows raw JSONL transcript entries
- Tabs for multiple sessions
- Pin-to-terminal from card hover

#### Recommendations:

1. **Smart Filtering**: Show tool calls collapsed by default, expand on click. Most of the transcript is tool results — users care about the assistant's text output and decisions.

2. **Progress Indicators**: Parse tool calls to show meaningful progress:
   - "Reading file X..." → 📄 icon
   - "Writing file Y..." → ✏️ icon  
   - "Running command Z..." → ⚙️ icon
   - Show a mini timeline: `[Read 3 files] → [Edited 2 files] → [Ran tests] → [Writing output]`

3. **Split View**: On desktop, allow the terminal to dock to the right side instead of bottom (like VS Code's terminal)

4. **Search**: Add Ctrl+F search within terminal output

5. **Export**: "Copy full transcript" button for debugging

### 1.6 Dark Theme Refinements

The current dark theme is well-designed with semantic color tokens (`--color-bg-base: #050810`, etc.). Some refinements:

1. **Contrast Issues**: `--color-content-muted: #64748b` on `--color-bg-elevated: #151c2c` is 3.4:1 ratio — below WCAG AA (4.5:1). Bump muted text to `#8892b0` for better readability.

2. **Accent Color Overload**: The red accent (`#ff4d4d`) is used for both primary actions AND error states. This creates visual confusion — "Is that NEXT button an action or a warning?"
   - **Recommendation:** Change primary accent to a teal/cyan (`#00e5cc`) or keep red but use yellow/amber for warnings.

3. **Light Theme Option**: Some users prefer light themes. The semantic token system makes this easy — just swap the `@theme` values. Consider adding a toggle.

4. **Status Column Colors**: Add subtle background tints to columns based on their semantic meaning:
   - Inbox: neutral gray
   - Up Next: subtle blue tint
   - In Progress: subtle amber tint  
   - In Review: subtle purple tint
   - Done: subtle green tint

---

## 2. Feature Recommendations (Ranked)

Ranked by impact × effort ratio. Each feature is evaluated for a user managing 5-10 AI agents daily.

### Tier 1: Must-Have (Do First)

#### 2.1 ⭐ Live Agent Output Streaming (WebSocket)

**Current:** 15-second polling via `kanban_refresh_controller.js` + 2.5-second polling for agent activity.

**Problem:** You're making 24 requests/minute per open task just for agent activity. On a busy day with 5 agents, that's 120 req/min of polling overhead. And there's still a 2.5s delay before you see new output.

**Recommendation:** Replace polling with **ActionCable channels** for real-time streaming:

```ruby
# app/channels/agent_activity_channel.rb
class AgentActivityChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_activity_task_#{params[:task_id]}"
  end
end
```

When the agent writes to the JSONL transcript, a file watcher (or the API endpoint itself) broadcasts the new entry. The Stimulus controller subscribes via WebSocket instead of polling.

**Impact:** Instant updates, 90% fewer HTTP requests, genuine real-time feel.
**Effort:** Medium (Rails 8 Solid Cable already configured, need file watcher or API broadcast hook)

#### 2.2 ⭐ Notification System

**Current:** No notifications at all. If you close the browser tab, you miss everything.

**Recommendation:** Multi-channel notification system:

1. **Browser notifications** (via Service Worker — PWA already registered):
   - Agent completed task → "📟 Otacon finished: Fix auth bug → In Review"
   - Agent errored → "⚠️ Task #103 failed: Rate limit exceeded"
   - Review passed/failed → "✅ Validation passed for: Fix auth bug"

2. **In-app notification center** (bell icon in header):
   - Unread count badge
   - List of recent events with timestamps
   - Click to navigate to relevant task

3. **Telegram integration** (since the user already uses Telegram):
   - POST to Telegram bot when key events happen
   - Configurable: which events to notify about

4. **Sound alerts** (opt-in):
   - Subtle chime on task completion
   - Alert tone on errors

**Impact:** Massive — this is the difference between actively monitoring and trusting the system.
**Effort:** Medium-High

#### 2.3 ⭐ Task Templates / Quick-Create Workflows

**Current:** Creating tasks requires filling out name + description + model + priority manually every time. Recurring tasks exist but are basic (daily/weekly/monthly repeat).

**Problem:** Most agent tasks follow patterns: "Review PR", "Fix bug in X", "Write tests for Y", "Research Z". Creating them is repetitive.

**Recommendation:**

1. **Task Templates**: Predefined templates with pre-filled description, model, tags, and validation command:
   ```
   Templates:
   🔍 Code Review    → model: opus, validation: bin/rails test, tag: review
   🐛 Bug Fix        → model: sonnet, tag: bugfix  
   📝 Documentation  → model: glm, tag: docs
   🧪 Write Tests    → model: codex, validation: bin/rails test
   🔬 Research       → model: gemini, tag: research
   ```

2. **Slash commands** in the inline-add input:
   - `/review Fix login page` → Creates a code review task with opus model
   - `/bug Auth bypass in API` → Creates a bug fix task
   - `/research Top 5 kanban tools` → Creates a research task with gemini

3. **Batch task creation**: Paste a multi-line list, each line becomes a task:
   ```
   Fix login validation
   Add password reset flow  
   Update API documentation
   → Creates 3 tasks in inbox
   ```

**Impact:** High — reduces task creation friction from 30s to 3s.
**Effort:** Low-Medium

#### 2.4 ⭐ Task Dependencies / Blocking

**Current:** Tasks have `blocked` boolean but no way to specify *what* they're blocked on. Parent-child links exist (via `parent_task_id`) but there's no dependency enforcement.

**Recommendation:**
- Add `blocked_by_task_id` field
- When blocker completes → auto-unblock dependent tasks
- Visual indicator: show "Blocked by: #103 Fix auth" on the card
- API endpoint: `POST /tasks/:id/add_dependency` / `DELETE /tasks/:id/remove_dependency`
- Board view: dotted line between blocker and blocked task (optional, can be toggle)

**Impact:** High — enables complex multi-step agent workflows.
**Effort:** Medium

### Tier 2: High-Value (Do Next)

#### 2.5 Analytics & Reporting Dashboard

**Current:** No analytics at all. The `task_activities` table has rich data but it's only shown as a log per task.

**Recommendation — `/analytics` page:**

1. **Agent Throughput**: Tasks completed per day/week (line chart)
2. **Model Usage**: Pie chart of which models are used most
3. **Time to Complete**: Average time from assigned → done, by model
4. **Error Rate**: Failures per model, trending over time
5. **Review Pass Rate**: What % of tasks pass validation on first try
6. **Cost Estimation**: Rough token cost estimates per model per task

Data source: All of this can be derived from `task_activities` + `tasks` table. Add a `completed_duration_seconds` field on task completion for accurate timing.

**Impact:** Medium-High — enables data-driven decisions about model selection.
**Effort:** Medium

#### 2.6 Bulk Operations

**Current:** Operations are one-task-at-a-time. Archiving 20 done tasks requires 20 clicks.

**Recommendation:**
- Checkbox selection mode (toggle via button or Shift+click)
- Bulk actions: Move to status, Assign to agent, Change model, Archive, Delete
- "Select all in column" shortcut
- "Archive all done tasks" one-click button (the `delete_confirm_all_tasks_controller.js` exists but only for delete, not archive)

**Impact:** Medium — saves significant time during cleanup.
**Effort:** Low

#### 2.7 Task Search & Filter

**Current:** Tag filtering exists (sidebar). No text search, no filter by model, no filter by date range.

**Recommendation:**
- **Global search bar** in header: Search across all boards by task name/description
- **Filter bar** below board tabs: Status, Model, Priority, Date range, Has error, Has review
- **Saved filters**: "Show me all opus tasks from this week with errors"
- Keyboard shortcut: `/` to focus search (like GitHub)

**Impact:** Medium-High as task volume grows.
**Effort:** Medium

#### 2.8 Collaborative Multi-User Support

**Current:** Single-user only. Auth exists (email/password + GitHub OAuth) but all tasks belong to one user.

**Recommendation (future):**
- Workspace/Organization model above User
- Shared boards with role-based access
- Agent assignment per user (multiple humans, one agent each)
- Activity feed showing "Gonzalo moved Task #103 to In Review"

**Impact:** Critical for adoption beyond single user.
**Effort:** High (significant schema changes)

### Tier 3: Nice-to-Have (Backlog)

#### 2.9 Calendar View
- Show tasks by due date in a calendar grid
- Nightly tasks shown at their scheduled time
- Recurring tasks shown on their recurrence dates

#### 2.10 Kanban WIP Limits
- Set maximum tasks per column
- Visual warning when column is at capacity
- Prevent adding more tasks to full columns (agent won't pick up new work)

#### 2.11 Time Tracking
- Track time spent per task (agent time + human review time)
- Cost per task estimation
- Integration with billing/invoicing systems

#### 2.12 Git Integration
- Show git diff preview for tasks that produced code changes
- Link commits to tasks via branch naming convention
- Auto-create tasks from GitHub issues

#### 2.13 AI-Powered Task Decomposition
- Given a high-level goal, AI breaks it into subtasks
- Creates a task tree with dependencies
- Assigns optimal model per subtask based on complexity

#### 2.14 Custom Workflows / Status Columns
- User-defined status columns beyond the fixed 6
- Workflow automation: "When task moves to X, do Y"
- Conditional logic: "If review fails, auto-handoff to opus"

---

## 3. OpenClaw Integration — Seamless Onboarding

### 3.1 Current State (Pain Points)

The current integration flow requires:
1. Copy API token from Settings page
2. Copy the massive agent prompt (50+ lines)
3. Paste into OpenClaw agent's HEARTBEAT.md or prompt configuration
4. Manually configure gateway URL and token in Settings
5. Hope the agent discovers the right endpoints

This is **expert-level configuration**. No new user will get through this without hand-holding.

### 3.2 Settings Page Integration Wizard

Design for a **guided setup experience** that replaces the current "wall of text" approach:

#### Step 1: Detection

```
┌─────────────────────────────────────────────────┐
│  🦞 Connect to OpenClaw                         │
│                                                  │
│  Checking for OpenClaw on this machine...        │
│                                                  │
│  ✅ OpenClaw Gateway detected at localhost:18789  │
│  ✅ Version: 1.2.3                               │
│  ✅ Agent: Otacon (📟)                           │
│                                                  │
│  [Connect Automatically]    [Manual Setup →]     │
└─────────────────────────────────────────────────┘
```

**Implementation:**
```ruby
# app/controllers/api/v1/settings_controller.rb
def detect_openclaw
  # Try common ports: 18789 (gateway), 4000 (old default)
  ports = [18789, 4000, 4001]
  
  ports.each do |port|
    begin
      uri = URI("http://localhost:#{port}/api/status")
      response = Net::HTTP.get_response(uri)
      if response.code == "200"
        data = JSON.parse(response.body)
        render json: { 
          found: true, 
          url: "http://localhost:#{port}",
          version: data["version"],
          agent_name: data["agent_name"]
        }
        return
      end
    rescue => e
      next
    end
  end
  
  render json: { found: false }
end
```

#### Step 2: Authentication Exchange

```
┌─────────────────────────────────────────────────┐
│  🔑 Link Your Agent                             │
│                                                  │
│  We'll exchange tokens so ClawTrol and OpenClaw  │
│  can communicate securely.                       │
│                                                  │
│  Gateway Token: ●●●●●●●●●●●● [Auto-detected]   │
│  ClawTrol Token: ctok_a3b5260d... [Generated]    │
│                                                  │
│  [Link Agent]                                    │
└─────────────────────────────────────────────────┘
```

**Flow:**
1. ClawTrol reads `~/.openclaw/config.yaml` to get gateway token (if on same machine)
2. Generates API token automatically
3. Saves gateway URL + token to user settings
4. Sends ClawTrol API token to OpenClaw via gateway API

#### Step 3: Agent Configuration

```
┌─────────────────────────────────────────────────┐
│  📋 Configure Your Agent                        │
│                                                  │
│  Agent Name: [Otacon          ]                  │
│  Agent Emoji: 📟 (click to change)              │
│  Auto-mode: [✅ On]                              │
│                                                  │
│  Model Preferences:                              │
│  Default Model: [Opus ▼]                         │
│  Fallback Chain: opus → sonnet → gemini → glm    │
│                                                  │
│  [Save & Continue →]                             │
└─────────────────────────────────────────────────┘
```

#### Step 4: Test Connection

```
┌─────────────────────────────────────────────────┐
│  🧪 Testing Connection                          │
│                                                  │
│  ✅ Gateway responds (87ms)                      │
│  ✅ Agent identified: Otacon 📟                  │
│  ✅ Webhook configured                           │
│  ✅ Token valid                                   │
│                                                  │
│  🎉 You're all set!                              │
│                                                  │
│  [Create Your First Task →]                      │
└─────────────────────────────────────────────────┘
```

#### Step 5: Connection Status Widget

After setup, show a persistent connection status in the header:

```
📟 Otacon ● Online  |  Last active: 2 min ago  |  3 tasks in flight
```

When disconnected:
```
📟 Otacon ○ Offline  |  Last seen: 1 hour ago  |  [Reconnect]
```

### 3.3 ClawTrol as OpenClaw Skill/Plugin

**Concept:** Package ClawTrol as an OpenClaw skill that agents can install.

```yaml
# ~/.openclaw/skills/clawtrol/SKILL.md
name: clawtrol
description: Task management dashboard for agent orchestration
install: docker-compose up -d
url: http://localhost:4001
```

**Benefits:**
- One-command install: `openclaw skill install clawtrol`
- Auto-configured: skill installer handles token exchange
- Discoverable: appears in OpenClaw's skill list

**Implementation approach:**
1. Create `openclaw-skill.yaml` manifest in ClawTrol repo
2. Define skill interface methods: `list_tasks`, `claim_task`, `complete_task`
3. OpenClaw skill loader reads the manifest and registers ClawTrol

### 3.4 Docker Compose for One-Click Deployment

```yaml
# docker-compose.yml
version: '3.8'
services:
  clawtrol:
    build: .
    ports:
      - "4001:3000"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/clawtrol
      - SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}
      - OPENCLAW_GATEWAY_URL=http://host.docker.internal:18789
    depends_on:
      - db
    restart: unless-stopped
    
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: clawtrol
      POSTGRES_PASSWORD: postgres

volumes:
  pgdata:
```

**One-liner install:**
```bash
curl -sSL https://raw.githubusercontent.com/wolverin0/clawtrol/main/install.sh | bash
```

The install script:
1. Clones the repo
2. Generates secrets
3. Runs `docker-compose up -d`
4. Opens browser to `http://localhost:4001`
5. Detects OpenClaw and pre-configures the connection

### 3.5 ClawTrol as OpenClaw's Built-in Control UI

**Vision:** ClawTrol ships as part of OpenClaw itself, accessible at `http://localhost:18789/ui` (alongside the existing gateway API).

**How:**
- OpenClaw bundles ClawTrol as a Docker sidecar
- Gateway proxies `/ui/*` to ClawTrol
- Shared authentication (gateway token = ClawTrol token)
- Zero configuration needed

**Trade-offs:**
- (+) Frictionless setup — it's just there
- (+) Shared auth — no token exchange needed
- (-) Coupling — ClawTrol updates require OpenClaw releases
- (-) Heavier OpenClaw Docker image

**Recommendation:** Offer both standalone and bundled modes. The bundled mode is for "just works" onboarding. Power users can run standalone for custom deployment.

---

## 4. The "10-Minute Setup" Vision

### Target User
A developer who already uses OpenClaw with Claude Code via Telegram. They want a visual dashboard to manage their agent fleet.

### Timeline

#### Minute 0-2: Install

```bash
# Option A: Docker (recommended)
curl -sSL https://clawtrol.dev/install.sh | bash
# Installs, starts, opens browser

# Option B: From source (for contributors)
git clone https://github.com/wolverin0/clawtrol.git
cd clawtrol && bin/setup
```

User sees: Registration page. Creates account with email/password.

#### Minute 2-4: Connect Agent

After registration, the onboarding wizard (not a settings page!) starts:

```
Welcome to ClawTrol! Let's connect your AI agent.

Step 1 of 3: Find OpenClaw
[Scanning... ✅ Found at localhost:18789]

Step 2 of 3: Link Agent  
[Connecting... ✅ Agent "Otacon" linked]

Step 3 of 3: Ready!
Your agent will check for tasks on every heartbeat.
```

The wizard automatically:
- Detects OpenClaw gateway
- Exchanges tokens
- Configures webhook for instant task triggering
- Sets up the HEARTBEAT.md entry for task polling

#### Minute 4-6: Create First Task

The wizard creates a demo board and prompts:

```
🎯 Create your first task!

What do you want your agent to work on?
[Write a Python script that fetches weather data from OpenWeatherMap API]

Model: [Sonnet ▼]  Priority: [Medium]

[Send to Agent →]
```

The task is created with `status: in_progress` and `assigned_to_agent: true`. The webhook fires instantly.

#### Minute 6-8: Watch Agent Work

The wizard opens the task panel with live agent activity:

```
📟 Otacon is working on: Write weather script

🤖 I'll create a Python script to fetch weather data...
🔧 Write → weather.py
🤖 The script is ready. It fetches current weather by city name...
📄 Output file: weather.py
```

User sees the agent thinking and working in real-time. The terminal panel shows the full transcript.

#### Minute 8-10: Review Output

Agent completes → task moves to "In Review":

```
✅ Task Complete!

📁 Files produced:
  • weather.py

📝 Agent Summary:
Created a Python script that fetches weather data from
OpenWeatherMap API. Supports city lookup, displays temp,
humidity, and wind speed.

[✅ Approve] [↪️ Follow-up] [🔄 Retry with Different Model]
```

User clicks "Approve" → task moves to Done. Confetti animation plays. 🎉

**Total time:** Under 10 minutes from zero to seeing AI work managed through a visual dashboard.

### Critical Path Dependencies

For this flow to work, these must be implemented:
1. ✅ Docker compose setup (Section 3.4)
2. ✅ Auto-detection wizard (Section 3.2)  
3. 🔲 Onboarding flow controller (new)
4. 🔲 Webhook auto-configuration
5. 🔲 First-task wizard UI
6. 🔲 Confetti on first task completion (canvas-confetti already vendored!)

---

## 5. Competitive Analysis

### 5.1 The Competitive Landscape

There are **no direct competitors** to ClawTrol. This is both a massive opportunity and a challenge (no established category to borrow from).

#### Adjacent Tools:

| Tool | What It Does | How ClawTrol Differs |
|------|-------------|---------------------|
| **Linear** | Modern project management | No AI agent integration, no live transcript viewing, no model routing |
| **Trello** | Classic kanban | No AI features at all, just boards and cards |
| **GitHub Projects** | Issue/PR tracking | Tied to GitHub, no agent orchestration, no real-time agent monitoring |
| **Plane** | Open-source Linear alternative | Generic project management, no AI-agent-specific features |
| **AgentOps / LangSmith** | LLM observability | Monitoring-only, no task management, no kanban, no assignment workflow |
| **Claude Code CLI** | Direct CLI usage | No visual dashboard, no multi-agent orchestration, no history/review |
| **Cursor/Windsurf** | AI-native IDEs | IDE-bound, single agent, no kanban, no orchestration across multiple agents |
| **n8n / Zapier** | Workflow automation | No kanban, no agent monitoring, no task review workflow |

#### Closest Conceptual Competitor: **Devin** (Cognition AI)
- Devin is an "AI software engineer" with its own web IDE
- It has a task management interface, but it's tied to Devin's proprietary agent
- ClawTrol is **model-agnostic** — works with any OpenClaw-compatible agent/model
- ClawTrol is **open source** — Devin is $500/month closed source

### 5.2 ClawTrol's Unique Value Proposition

> **"The mission control center for your AI agent fleet."**

What makes ClawTrol unique:

1. **Model-Agnostic Agent Orchestration**: Assign tasks to any AI model (Opus, Sonnet, Codex, Gemini, GLM) with automatic fallback when models are rate-limited.

2. **Live Agent Transparency**: Watch your agents think and work in real-time. See every tool call, every file edit, every decision — not just the final output.

3. **Human-in-the-Loop Review Workflow**: Tasks flow through a structured pipeline (Inbox → Up Next → In Progress → In Review → Done) with validation commands and multi-model debate reviews.

4. **Open Source & Self-Hosted**: Your data stays on your machine. No vendor lock-in. Fork it, modify it, integrate it.

5. **Purpose-Built for AI Agents**: Not a generic kanban retrofitted for AI — every feature (model routing, session linking, context tracking, handoff, auto-claim) was designed for the agent workflow.

### 5.3 Why Choose ClawTrol Over Claude Code CLI Directly?

For a developer who already uses Claude Code via Telegram:

| Aspect | CLI Only | CLI + ClawTrol |
|--------|----------|----------------|
| **Visibility** | One agent at a time in terminal | All agents visible on one screen |
| **History** | Scroll through terminal history | Persistent task history with search |
| **Model Management** | Manual model switching | Auto-fallback, rate limit tracking |
| **Review Process** | Read terminal output | Structured review with validation & debate |
| **Follow-ups** | Remember what to do next | Linked follow-up tasks with AI suggestions |
| **Delegation** | Tell agent what to do each time | Queue up 10 tasks, agent works through them |
| **Error Recovery** | Notice errors in terminal | Error badges, auto-retry, model handoff |
| **Metrics** | None | Completion rate, time-to-done, model usage |

**The killer argument:** "Without ClawTrol, you're a manager who can only talk to one employee at a time. With ClawTrol, you have a war room with a whiteboard showing all work in progress."

---

## 6. Implementation Priorities

### Phase 1: Foundation (Weeks 1-3)
*Focus: Fix what's clunky, build the integration wizard*

1. **Settings wizard** (Section 3.2) — Replace wall-of-text settings with guided setup
2. **Docker compose** (Section 3.4) — Enable one-command install
3. **Task card simplification** (Section 1.1A) — Progressive disclosure, reduce visual noise
4. **Notification system** (Section 2.2) — Browser + in-app notifications
5. **Undo toast** for status changes (Section 1.2C)

### Phase 2: Real-Time & Templates (Weeks 4-6)
*Focus: Make daily usage delightful*

6. **WebSocket streaming** (Section 2.1) — Replace polling with ActionCable
7. **Task templates** (Section 2.3) — Slash commands + predefined templates
8. **Dashboard page** (Section 1.4) — Overview across all boards
9. **Mobile single-column view** (Section 1.3)
10. **Keyboard shortcuts** (Section 1.1C)

### Phase 3: Power Features (Weeks 7-10)
*Focus: Features that make power users stay*

11. **Analytics page** (Section 2.5)
12. **Task dependencies** (Section 2.4)
13. **Bulk operations** (Section 2.6)
14. **Search & filter** (Section 2.7)
15. **Agent terminal improvements** (Section 1.5)

### Phase 4: Growth (Weeks 11+)
*Focus: Multi-user, ecosystem integration*

16. **OpenClaw skill packaging** (Section 3.3)
17. **Multi-user support** (Section 2.8)
18. **Git integration** (Section 2.12)
19. **AI task decomposition** (Section 2.13)
20. **Custom workflows** (Section 2.14)

---

## Appendix A: Technical Debt to Address

Identified during codebase review:

1. **Schema cruft**: 4 orphan tables (projects, task_lists, tags, task_tags) from pre-board migration. Clean up with a migration.

2. **N+1 queries**: `boards#show` loads tasks with includes but the `_task_card` partial accesses `task.board` and `task.user` which may not always be preloaded during Turbo Stream broadcasts.

3. **Asset bloat**: `public/assets/` has 40+ old versioned assets that should be cleaned up by `rails assets:clobber`.

4. **Inline JavaScript**: Board settings modal uses inline `<script>` tags with `onclick` handlers. Should be migrated to Stimulus controllers.

5. **`detect_board_for_task` hardcoding**: The `spawn_ready` board routing is hardcoded to specific board names ("ClawDeck", "Pedrito", "Misc"). Should use a configurable mapping or the auto_claim_prefix system.

6. **Debate job is a stub**: `RunDebateJob` generates a fake synthesis.md instead of actually running a multi-model debate. Needs real implementation with API calls to multiple models.

7. **Missing test coverage**: API controller tests exist but system tests are minimal. The complex agent activity/terminal features have no tests.

## Appendix B: Quick Wins (< 1 Day Each)

1. Add "done today" counter to header
2. Add keyboard shortcut `n` for new task
3. Add `Ctrl+/` to toggle agent terminal
4. Show model color on card left border
5. Add "Copy task URL" button in task modal
6. Show parent task link in card (for follow-ups)
7. Add "Retry" button on errored tasks (currently only handoff)
8. Confetti on first task completion (already have `canvas-confetti` vendored!)
9. Add loading skeleton for task cards during refresh
10. Show "Created X time ago" in task modal footer

---

*This roadmap is a living document. Priorities should be reassessed monthly based on actual usage patterns and user feedback.*
