# ClawDeck Agent Integration - Phase 2

## Summary

This release focuses on **agent workflow automation** and **mobile responsiveness**. Key highlights include new API endpoints for automated agent tracking, a complete mobile UI overhaul with bottom sheet modals, and extensive bug fixes for the Kanban board and hover preview systems.

---

## 🚀 New Features

### Agent Automation Endpoints
- **spawn_ready & link_session API endpoints** (`a488afd`): Enable automated agent tracking - agents can now signal readiness and link their sessions programmatically

### Mobile Experience
- **Mobile-friendly agent preview** (`36bc40e`): Bottom sheet modal pattern for touch devices (Task #32)
- **Mobile terminal toggle + pin** (`0625987`): Pin tasks to terminal directly from mobile modal

### Task Preview & Interaction
- **Real-time agent preview on hover** (`3e856c0`): See live agent activity by hovering over tasks
- **Hover preview extended to in_review tasks** (`b2d810d`): Preview available across more workflow stages
- **Parent output in follow-up modal** (`eb8b48e`): View parent task output when creating follow-ups

### Quick Actions
- **Task ID display + NEXT/Follow-up buttons** (`2b86861`): Quick action buttons visible on task cards
- **Always-visible action buttons** (`3e856c0`): No more hunting for actions

---

## 🐛 Bug Fixes

### Kanban Board Ordering
- **Fixed column ordering with reorder()** (`0d3bf8c`): Override default_scope for correct column display
- **Sort in_review/done by most recent** (`a77fc94`): Latest tasks appear first
- **Disabled sorting in completed columns** (`ba97f19`): Maintain date-based order, re-prepend on update
- **NEXT button persists after drag** (`36bc40e`): Button no longer disappears between columns

### Hover Preview System
- **Hide preview when context menu opens** (`da04815`): No more overlapping UI elements
- **Context menu z-index fix** (`1a896b2`): Menu always appears above preview
- **Fixed positioning for overflow** (`8d7efe7`): Preview no longer clipped by containers
- **Modal fallback for transcript** (`073d18c`): Falls back to description if no transcript

### Mobile Modals
- **Proper bottom sheet pattern** (`cf5784b`): Modals slide up correctly on mobile
- **Centered modal pattern** (`a508d24`): Agent modal matches follow-up modal styling
- **Mobile slide animation** (`05a1e8d`): Smooth upward animation on open

### Terminal & Events
- **Pin event dispatch fix** (`59b4754`): Events now dispatch to document (not window)
- **Increased truncation limits** (`a9d6dbd`, `cd5a8c7`): Terminal: 5000/1500/3000 chars for better readability
- **Content limits & fallback regex** (`ff6b5da`): More robust content parsing

### API & Auth
- **Session auth for AI suggestions** (`e561a2a`): Uses session auth instead of API token
- **Session continuation UI** (`4dcd707`): Shows continuation UI even without session_key
- **GLM thinking mode disabled** (`d6cee81`): Proper content response from GLM models

### UI/UX Polish
- **NEXT button uses link_to** (`011e659`): Proper navigation instead of form submission
- **Action buttons outside link wrapper** (`4fef071`): Prevents click propagation issues
- **Follow-up modal improvements** (`1cb9a0b`): Better UX flow
- **Async follow-up + model selector** (`a1c973e`): Non-blocking modal with model choice

---

## 🔧 Improvements

- **Agent integration enhancements** (`df3b90a`): Foundation for Phase 2 features
- **Documented session key requirement** (`eb8b48e`): Clear documentation for integration

---

## 📝 Technical Notes

### New API Endpoints
```
POST /api/v1/tasks/:id/spawn_ready  - Signal agent is ready
POST /api/v1/tasks/:id/link_session - Link agent session to task
```

### Event System
- Pin-to-terminal events now use `document` dispatch instead of `window`
- Custom events: `agent-terminal:pin`, `agent-terminal:unpin`

### Content Limits (Agent Activity Panel)
- Full content: 5000 chars
- Truncated preview: 1500 chars  
- Terminal view: 3000 chars

---

## 🧪 Testing Notes

### Critical Paths to Test
1. **Mobile flow**: Open task → view agent preview → pin to terminal → close modal
2. **Hover preview**: Hover task → right-click for context menu → verify z-index
3. **NEXT button**: Click NEXT → drag task to different column → verify button persists
4. **Agent automation**: Call spawn_ready → link_session → verify task updates

### Regression Checks
- [ ] Kanban drag-and-drop still works
- [ ] Column ordering correct (up_next, in_progress, in_review, done)
- [ ] Follow-up modal creates linked tasks
- [ ] AI suggestion generates properly with GLM models
- [ ] Terminal pin/unpin across multiple tasks

---

## ⚠️ Known Issues / TODOs

### Debug Logging (Consider Cleanup)
The following console.log statements exist in JS controllers:
- `agent_activity_controller.js` (2 logs)
- `agent_preview_controller.js` (2 logs)
- `agent_terminal_controller.js` (5 logs)

These are useful for debugging but could be wrapped in a debug flag or removed for production.

---

*Generated: 2026-02-05*
