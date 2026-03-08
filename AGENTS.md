# AGENTS.md - ClawTrol Operational Guide

This file is the operational source-of-truth for AI coding assistants working on ClawTrol.

## 1) Operational Context (Critical)

Use this map first. Most recent confusion came from editing the wrong folder.

### Canonical vs mirror folders

| Role | Path | Status | Notes |
|---|---|---|---|
| Canonical ClawTrol codebase | `/home/ggorbalan/clawdeck` | **WRITE HERE** | Rails app, git repo, running service |
| ClawTrol docs mirror on Windows | `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol` | Mirror/docs only | No `.git`, do not treat as runtime codebase |
| Scratch patch dump | `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawdeck_remote_work` | Non-canonical | Isolated files, not the live repo |
| Repo comparison clones (Windows) | `G:\_OneDrive\OneDrive\Desktop\Py Apps\gitclones` | Reference only | For benchmarking patterns |
| Repo comparison clones (Ubuntu) | `/home/ggorbalan/gitclone` | Reference only | For benchmarking patterns |
| OpenClaw workspace | `/home/ggorbalan/.openclaw/workspace` | Separate project | Cognitive/memory files, not ClawTrol app code |

### Runtime endpoints

- ClawTrol app URL: `http://192.168.100.186:4001`
- Service unit: `systemctl --user status clawdeck-web.service`

## 2) Mandatory Preflight Before Any Edit

Run these checks in order before coding:

```bash
# 1) Confirm machine/repo
ssh ggorbalan@192.168.100.186 'cd ~/clawdeck && pwd && git rev-parse --show-toplevel'

# 2) Confirm branch + dirty state
ssh ggorbalan@192.168.100.186 'cd ~/clawdeck && git branch --show-current && git status --short'

# 3) Confirm target file exists in canonical repo
ssh ggorbalan@192.168.100.186 'cd ~/clawdeck && ls -la <target_path>'
```

If these do not point to `/home/ggorbalan/clawdeck`, stop and re-route.

## 3) Documentation Source-of-Truth Policy

- Canonical roadmap lives in: `docs/roadmaps/`
- Execution evidence lives in: `docs/reports/` and `docs/artifacts/`
- Session handoff context lives in: `handoff.md`

When roadmaps conflict:
1. Keep one canonical roadmap marked ACTIVE.
2. Mark older files as superseded, do not delete historical context.
3. Update checkbox status immediately after each completed step.

## 4) Project Overview

ClawTrol (formerly ClawDeck) is a Rails 8.1 mission control dashboard for AI agents.

Core capabilities:
- Task queue with board-based workflow
- Agent orchestration state (sessions, model routing, validation)
- Swarm idea launcher
- Factory loop automation
- ZeroBitch fleet controls
- Nightshift/cron orchestration

## 5) Architecture Snapshot

### Stack
- Ruby 3.3.x / Rails 8.1
- PostgreSQL (primary/cache/queue/cable)
- Solid Queue, Solid Cache, Solid Cable
- Hotwire (Turbo + Stimulus) + Tailwind
- Puma + Nginx deployment

### P0 Data Contract (Feb 2026)

**`tasks.description` is the HUMAN BRIEF only. Agent output goes to TaskRun.**

Key columns:
- `tasks.description` — Human task brief (never mutated by agents)
- `tasks.original_description` — Backup of original brief
- `tasks.execution_prompt` — Prompt for agent execution (was `execution_plan`)
- `tasks.compiled_prompt` — Pipeline-generated prompt from ERB templates
- `task_runs.agent_output` — Agent findings/output per run
- `task_runs.prompt_used` — Immutable snapshot of the prompt sent to agent
- `task_runs.agent_activity_md` — Markdown transcript summary
- `task_runs.follow_up_prompt` — Follow-up instructions for requeue

Prompt precedence chain: `compiled_prompt || execution_prompt || original_description || description || name`

**Reading agent output:**
```ruby
task.agent_output_text     # reads TaskRun first, falls back to description regex
task.has_agent_output?     # checks TaskRun OR description pattern
task.latest_run            # most recent TaskRun
task.effective_prompt      # prompt that would be sent to agent
task.description_section("Agent Output")  # legacy fallback only
```

### Key domains

- `Task` lifecycle: `inbox -> up_next -> in_progress -> in_review -> done`
- Factory loops: persistent automation cycles with logs/findings
- Swarm ideas: curated launch templates that create tasks
- ZeroBitch: external fleet/agent execution surface

## 6) Dev Commands

### Setup + run
```bash
bin/setup
bin/dev
bin/rails server
```

### DB
```bash
bin/rails db:prepare
bin/rails db:migrate
bin/rails db:reset
```

### Tests + quality
```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/ci
```

## 7) Merge Gate Baseline (Do Not Skip)

Any change intended for integration should pass:

1. Lint/static checks (`rubocop`, security checks where applicable)
2. Unit/integration tests for touched areas
3. E2E/system tests for user-facing flows changed
4. Route/UI smoke check for impacted endpoints
5. Evidence written to `docs/artifacts/` or `docs/reports/`

If any gate fails, do not mark task done.

## 8) Collaboration Rules for Agents

1. Edit code in `/home/ggorbalan/clawdeck` only.
2. Avoid broad refactors in dirty worktrees unless explicitly requested.
3. Never use destructive git commands (`reset --hard`, `checkout --`) unless asked.
4. When context is ambiguous, verify path + repo before touching files.
5. Prefer small reversible changes with explicit validation steps.
6. Keep roadmap checkboxes updated in the same execution window.

## 9) Common Pitfalls and Fixes

### Pitfall: "I changed files but app did not change"
Cause: edited a mirror/non-canonical folder.
Fix: re-run preflight, ensure edits happen in `/home/ggorbalan/clawdeck`.

### Pitfall: "Nav differs across pages"
Cause: duplicated nav partials drifting.
Fix: update all nav partials together and verify desktop + mobile.

### Pitfall: "Factory produced many commits but low trust"
Cause: missing merge gate/E2E evidence.
Fix: enforce merge gate baseline before integration.

## 10) API/Auth Notes

- API base: `/api/v1`
- Auth header:
  - `Authorization: Bearer <token>`
- Agent identity headers (when used):
  - `X-Agent-Name: <name>`
  - `X-Agent-Emoji: <emoji>`

## 11) Related Docs

- `docs/AGENT_INTEGRATION.md`
- `docs/OPENCLAW_INTEGRATION.md`
- `docs/API_REFERENCE.md`
- `docs/factory/ARCHITECTURE.md`
- `docs/roadmaps/`

## 12) Swarm/Factory/ZeroClaw (Exception Mode Only)

Default execution mode is the normal task flow:
- One task at a time
- Standard board pipeline
- Normal review and validation gates

Do not activate Swarm/Factory/ZeroClaw by default.

Activate this mode only when at least one trigger is true:
1. The roadmap explicitly marks a phase as `BURST`, `BATCH`, or `PARALLEL`.
2. There are 5+ related tasks that can be safely parallelized.
3. A large refactor needs isolated playground validation before merge.
4. The user explicitly asks for swarm/factory/zeroclaw execution.

When exception mode is active:
- Swarm orchestrates phases and dispatch.
- Factory runs high-volume experiments in isolated workspaces.
- ZeroClaw handles heavy parallel subtasks and returns artifacts.

Guardrail:
- Never bypass the normal merge gates.
- If exception mode is not clearly required, stay on regular task flow.

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->
