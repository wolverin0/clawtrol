# Soul Editor — Feature Spec for ClawDeck

## Overview
Add a Soul Editor page to ClawDeck — a full markdown editor for the 4 core OpenClaw workspace files (SOUL.md, IDENTITY.md, USER.md, AGENTS.md) with version history, persona templates, and keyboard shortcuts.

Inspired by VidClaw's SoulEditor (React) — adapted to Rails/Stimulus/Tailwind.

## Backend (Rails)

### Controller: `SoulEditorController`

```ruby
# app/controllers/soul_editor_controller.rb
class SoulEditorController < ApplicationController
  before_action :require_authentication
  WORKSPACE = File.expand_path("~/.openclaw/workspace")
  HISTORY_DIR = Rails.root.join("storage", "soul-history")
  ALLOWED_FILES = %w[SOUL.md IDENTITY.md USER.md AGENTS.md].freeze
  MAX_HISTORY = 20
end
```

Actions:
1. **show** — renders the editor page. Accepts `?file=SOUL.md` param (default: SOUL.md)
   - Reads file content from workspace
   - Gets last modified timestamp
   - Returns content + metadata as JSON if XHR, otherwise renders view
   
2. **update** (PATCH) — saves new content
   - Pushes old content to history JSON file first
   - Writes new content to workspace file
   - Returns success + new timestamp
   
3. **history** (GET) — returns version history for active file
   - Reads from `storage/soul-history/{filename}-history.json`
   - Each entry: `{timestamp: ISO8601, content: string}`
   - Max 20 entries, FIFO
   
4. **revert** (POST) — reverts to a specific history version
   - Saves current content to history first
   - Overwrites file with selected version
   - Returns new content
   
5. **templates** (GET) — returns 6 persona templates (only for SOUL.md)

### History Storage
- Directory: `storage/soul-history/`
- Files: `SOUL.md-history.json`, `IDENTITY.md-history.json`, etc.
- Format: JSON array of `{timestamp, content}` objects
- Max 20 entries per file, oldest removed first
- NO database migration needed

### Routes
```ruby
# config/routes.rb
get "soul-editor", to: "soul_editor#show"
patch "soul-editor", to: "soul_editor#update"
get "soul-editor/history", to: "soul_editor#history"
post "soul-editor/revert", to: "soul_editor#revert"
get "soul-editor/templates", to: "soul_editor#templates"
```

### Templates (hardcoded)
1. **Minimal Assistant** — "Be helpful. Be concise. No fluff."
2. **Friendly Companion** — warm, conversational, emoji
3. **Technical Expert** — precise, code-focused, opinionated
4. **Creative Partner** — brainstormy, imaginative
5. **Stern Operator** — military-efficient, dry humor
6. **Sarcastic Sidekick** — witty, helpful with commentary

## Frontend

### View: `app/views/soul_editor/show.html.erb`

Layout with Stimulus controller `data-controller="soul-editor"`:

1. **Tab bar** at top: `Soul | Identity | User | Agents`
   - Active tab highlighted with primary color + bottom border
   - Yellow dot indicator when content is dirty
   - Click switches file (with unsaved changes confirm)

2. **Main editor area** (flex-1):
   - Full-height `<textarea>` with:
     - Monospace font (`font-mono`)
     - Dark background (`bg-[#1a1a2e]`)
     - No resize
     - Focus ring on primary color
   - Preview mode: when previewing template/history, textarea becomes read-only with yellow "Preview" badge

3. **Bottom bar**:
   - Left: char count, last modified (relative time like "2m ago"), unsaved indicator
   - Right: Reset button (reload from disk), Save button (green flash on success)
   - Ctrl+S / Cmd+S keyboard shortcut for save

4. **Right sidebar** (w-72):
   - Two tabs: Templates (only for SOUL.md) | History
   - **Templates tab**: cards with name, description, click to preview, "Use Template" button
   - **History tab**: list of versions with relative timestamps, click to preview, "Revert" on hover

### Stimulus Controller: `app/javascript/controllers/soul_editor_controller.js`

Targets: textarea, charCount, lastModified, saveBtn, tabs, sidebar
Values: activeFile (string), content (string), savedContent (string), dirty (boolean)

Key behaviors:
- Tab key in textarea inserts 2 spaces
- Ctrl+S saves
- Dirty tracking (content !== savedContent)
- Fetch API calls to backend endpoints
- Preview mode management
- Confirm dialogs for unsaved changes

## Navigation
Add link to sidebar after existing "Identity & Branding" link:
- Icon: use an existing Lucide icon (e.g., `heart-pulse` or `pen-tool`)
- Label: "Soul Editor"
- Path: `/soul-editor`

## IMPORTANT CONSTRAINTS
- ClawDeck stack: Rails 8.1, Propshaft, Stimulus, Turbo, Tailwind CSS
- NO React, NO Vue, NO external JS frameworks
- NO database migrations — JSON file storage only
- DO NOT modify the actual workspace files' content beyond what the user edits
- DO NOT break existing identity config page (`/identity-config`)
- Match ClawDeck's existing dark theme and styling conventions
- Look at existing views/controllers for style reference (e.g., `app/views/identity_config/show.html.erb`)

## Files to create/modify
- NEW: `app/controllers/soul_editor_controller.rb`
- NEW: `app/views/soul_editor/show.html.erb`  
- NEW: `app/javascript/controllers/soul_editor_controller.js`
- MODIFY: `config/routes.rb` (add soul-editor routes)
- MODIFY: sidebar partial (find it — likely in layouts or a shared partial)
- NEW: `storage/soul-history/` directory (mkdir -p)
- NEW: `test/controllers/soul_editor_controller_test.rb` (basic tests)

## Verification
After building, verify:
1. `curl http://localhost:4001/soul-editor` returns 200 with the editor page
2. The textarea loads SOUL.md content
3. Switching tabs loads the correct file
4. Save writes to disk and appears in history
5. Templates load for SOUL.md tab
6. History shows previous versions
