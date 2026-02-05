# PR #16 - Agent Integration 2.0 (Updated)

## Summary
Comprehensive agent integration for ClawDeck with real-time monitoring, mobile support, and advanced workflow features.

---

## ✨ New Features

### 1. Agent Terminal Panel (Codec Style) 🖥️
- **Split-screen terminal** at bottom of page for monitoring agent activity
- **Multiple tabs** for pinned agents
- **Resizable** with drag handle
- **Green/Amber color schemes** (toggle in panel)
- **Keyboard shortcut**: `Ctrl+`` to toggle
- **Auto-scroll** with latest messages
- **LocalStorage persistence** across sessions
- **Floating toggle button** for mobile access

### 2. Session Continuation & Health Monitoring 🔋
- **Context health meter** shows session usage percentage
- **"Continue same session"** toggle in follow-up modal
- **Threshold warnings**: "⚠️ 82% used - recommend fresh start"
- **User settings** for threshold (default 70%)
- New fields: `agent_session_key`, `context_usage_percent`

### 3. Mobile-Friendly Agent Preview 📱
- **Bottom sheet modal** (slides up from bottom on mobile)
- **📟 button** visible on all cards with `agent_session_id`
- **Swipe-to-dismiss** gesture support
- **Touch-friendly**: 44x44px minimum tap targets
- **Action buttons** in modal: NEXT, Follow-up, Archive
- **Pin to Terminal** button for quick docking

### 4. Nightly Tasks 🌙
- `nightly: true` flag for tasks that run on "good night" trigger
- Optional `nightly_delay_hours` for staggered execution
- Context menu option: "Move to Nightly"

### 5. Follow-up System ↪️
- **AI-powered suggestions** via GLM/Z.AI
- **Enhance button** to improve task descriptions
- **Model selector** in follow-up modal
- **Destinations**: inbox, up_next, in_progress, nightly
- Follow-ups inherit parent's model preference

### 6. Quick Actions on Cards ⚡
- **Always-visible buttons**: NEXT →, Follow-up
- **Task ID** displayed on cards (#123)
- **Real-time hover preview** of agent activity
- Context menu with all actions

### 7. Webhook Auto-Trigger 🚀
- Configure Gateway URL + Token in Settings
- When task → `in_progress` + `assigned_to_agent`
- ClawDeck POSTs to gateway `/api/cron/wake`
- Agent wakes immediately (no heartbeat wait)

### 8. Settings Enhancements ⚙️
- **AI Settings**: Model selector, API key config
- **Gateway Webhook**: URL + Token for auto-trigger
- **Session Threshold**: Configure context health threshold
- **Comprehensive agent prompt** with full API docs

---

## 🐛 Bug Fixes
- Fix NEXT button not working (was inside link wrapper)
- Fix GLM thinking mode (disabled for proper content response)
- Fix hover preview content parsing (array structure)
- Fix asset compilation issues
- Fix drag-and-drop after asset changes

---

## 📁 Files Changed

### New Files
- `app/javascript/controllers/agent_terminal_controller.js` - Terminal panel
- `app/javascript/controllers/agent_modal_controller.js` - Mobile modal
- `app/javascript/controllers/agent_preview_controller.js` - Hover preview
- `app/javascript/controllers/session_health_controller.js` - Health meter
- `app/views/layouts/_agent_terminal.html.erb` - Terminal partial
- `app/views/boards/tasks/_agent_modal.html.erb` - Mobile modal
- `app/views/boards/tasks/followup_modal.html.erb` - Follow-up modal
- `app/views/boards/tasks/_handoff_modal.html.erb` - Handoff modal
- `app/services/ai_suggestion_service.rb` - AI integration
- `db/migrate/*_add_session_continuation_to_tasks.rb`
- `db/migrate/*_add_context_threshold_to_users.rb`
- `db/migrate/*_add_error_fields_to_tasks.rb`

### Modified Files
- `app/views/boards/_task_card.html.erb` - Action buttons, preview
- `app/views/boards/show.html.erb` - Terminal include
- `app/views/profiles/show.html.erb` - Settings sections
- `app/controllers/api/v1/tasks_controller.rb` - New endpoints
- `app/controllers/boards/tasks_controller.rb` - Actions
- `app/models/task.rb` - New fields, scopes
- `config/routes.rb` - New routes

---

## 🔌 API Additions

### Endpoints
- `GET /api/v1/tasks/:id/session_health` - Check session context usage
- `POST /api/v1/tasks/:id/generate_followup` - AI suggestion
- `POST /api/v1/tasks/:id/create_followup` - Create follow-up
- `POST /api/v1/tasks/:id/handoff` - Handoff to another model

### Task Fields (new)
- `agent_session_key` (string) - Spawnable session key
- `context_usage_percent` (integer) - Last known context %
- `nightly` (boolean) - Run on "good night"
- `nightly_delay_hours` (integer) - Delay before execution
- `error_message` (text) - Error description
- `error_at` (datetime) - When error occurred

### User Fields (new)
- `context_threshold_percent` (integer, default: 70)
- `openclaw_gateway_url` (string)
- `openclaw_gateway_token` (string)
- `ai_suggestion_model` (string)
- `ai_api_key` (string)

---

## 🎮 Usage

### Pin Agent to Terminal
1. Hover over a task card with agent activity
2. Click "PIN TO TERMINAL" in preview
3. Or: Tap 📟 button → "Pin to Terminal"
4. Terminal panel appears at bottom
5. `Ctrl+`` to toggle visibility

### Create Follow-up
1. Complete a task (move to in_review)
2. Context menu → "Create Follow-up"
3. Optional: Generate AI suggestion
4. Choose destination: inbox, up_next, etc.
5. Toggle "Continue same session" if healthy

### Configure Webhook
1. Go to Settings → OpenClaw Integration
2. Enter Gateway URL (e.g., `http://localhost:18789`)
3. Enter Gateway Token (from config.yaml)
4. Save → Tasks auto-trigger agent wake

---

## 📸 Screenshots
[Add screenshots of terminal panel, mobile modal, settings]

---

## Migration Required
```bash
bin/rails db:migrate
```

## Testing
- [x] Terminal panel with multiple tabs
- [x] Mobile bottom sheet modal
- [x] Session health indicator
- [x] Follow-up creation flow
- [x] Webhook trigger
- [x] AI suggestions (requires Z.AI key)
