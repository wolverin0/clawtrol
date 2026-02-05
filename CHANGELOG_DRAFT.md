# ClawDeck v0.2.0 - Agent Integration & Multi-Board Support

## 🎯 Multi-Board System

### Board Management
- **Multiple Boards**: Support for ClawDeck, Pedrito, Misc (and custom boards)
- **Board Tabs Navbar**: Horizontal tab navigation with real-time task count badges
- **Auto-Routing**: Automatically detect project from task name keywords (e.g., "ClawDeck:" → ClawDeck board)
- **Move to Board**: Context menu option to move tasks between boards with Turbo Stream updates
- **Board Status API**: New endpoint `/api/v1/boards/:id/status` for real-time board stats

## 🔄 Auto-Refresh Kanban

- **Polling Refresh**: Kanban board automatically refreshes every 15 seconds
- **Badge Updates**: Task count badges update without full page reload
- **Graceful Degradation**: Network errors handled silently, retry on next interval
- **New Controller**: `kanban_refresh_controller.js` for Stimulus-based polling

## 🖥️ Terminal & Preview Improvements

### Agent Terminal
- **Tab Switching**: Switch between active agent tasks without closing terminal
- **Board Icons**: Display board icon next to task names in terminal header
- **X Button Fix**: Close button now properly closes terminal panel
- **Content Caching**: Cached task content prevents re-fetching on tab switch

### Task Preview
- **Z-Index Stack**: Proper layering - preview (1040) → dropdown (1045) → terminal (1050) → modal (1060)
- **Dropdown Handling**: Context menus properly stack above preview panels

## 🔐 Authentication & API

- **Session Health Endpoint**: `/api/v1/tasks/session_health` - no auth required for agent polling
- **Session Auth Fallback**: Browser requests can use session cookies as API auth fallback
- **Auto-Done on Follow-up**: Tasks automatically marked done when creating follow-up tasks

## 🐛 Bug Fixes

- Fixed dropdown menu z-index in all contexts (task cards, preview, terminal)
- Fixed preview panel positioning when scrolled
- Fixed terminal visibility toggle edge cases
- Fixed board icon display in agent modal pin button
- Fixed move_to_board Turbo Stream response handling

## 📁 New Files

- `app/javascript/controllers/kanban_refresh_controller.js` - Auto-refresh controller
- `app/views/boards/tasks/move_to_board.turbo_stream.erb` - Move to board response

## 📝 Modified Files

- `app/controllers/api/v1/boards_controller.rb` - Board status endpoint
- `app/controllers/api/v1/tasks_controller.rb` - Session health, auto-routing
- `app/controllers/boards/tasks_controller.rb` - Move to board action
- `app/controllers/concerns/api/token_authentication.rb` - Session auth fallback
- `app/javascript/controllers/agent_modal_controller.js` - Board icon for pin
- `app/javascript/controllers/agent_preview_controller.js` - Z-index fixes
- `app/javascript/controllers/agent_terminal_controller.js` - Tab switching, caching
- `app/views/boards/_header.html.erb` - Board tabs navbar
- `app/views/boards/_task_card.html.erb` - Move to board submenu
- `app/views/boards/show.html.erb` - Auto-refresh controller
- `config/routes.rb` - New routes for status and move_to_board
