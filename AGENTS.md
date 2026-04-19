# AGENTS.md - ClawTrol Operational Guide

This file is the operational source-of-truth for AI coding assistants working on ClawTrol.

## 1) Operational Context (Critical)

Use this map first. Most recent confusion came from editing the wrong folder.

### Canonical vs mirror folders

**UPDATED 2026-04-19** — Workflow shifted from SSH-edit-on-VM to local-clone + deploy-to-VM. The Windows local dir now holds a FULL git clone, not a docs mirror. Edits happen locally; deploys use `/deploy-to-vm` skill.

| Role | Path | Status | Notes |
|---|---|---|---|
| **Local working copy (primary)** | `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol` | **WRITE HERE** | Full clone of `wolverin0/clawtrol`, same remote as VM. Work locally, deploy via `/deploy-to-vm`. |
| VM deployment target | `/home/ggorbalan/clawdeck` | Pulled-from-git | Running Rails service, pulls from origin. Do NOT edit directly unless debugging on the VM is required. |
| VM worktree (alternate branch) | `/home/ggorbalan/factory-workspaces/clawtrol-minimax` | Secondary working copy | Git worktree of `~/clawdeck/.git`. Separate branch, separate working dir. |
| Audit workspace (archived) | `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol-workspace` | Preserved audit docs | AUDIT.md, FIX_PROMPTS.md, FEATURE_IDEAS.md, roadmap.md, obsidian-vault/, screenshots. Moved aside from clawtrol/ during the 2026-04-19 re-clone. Reference only. |
| Scratch patch dump | `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawdeck_remote_work` | Non-canonical | Isolated files from prior remote-work flow, not the live repo |
| Repo comparison clones (Windows) | `G:\_OneDrive\OneDrive\Desktop\Py Apps\gitclones` | Reference only | For benchmarking patterns |
| Repo comparison clones (Ubuntu) | `/home/ggorbalan/gitclone` | Reference only | For benchmarking patterns |
| OpenClaw workspace | `/home/ggorbalan/.openclaw/workspace` | Separate project | Cognitive/memory files, not ClawTrol app code |

### Runtime endpoints

- ClawTrol app URL: `http://192.168.100.186:4001`
- Service unit: `systemctl --user status clawdeck-web.service` (or via `docker compose ps` in `~/clawdeck/`)

### Deploy

Use the `/deploy-to-vm` skill at `.claude/skills/deploy-to-vm/SKILL.md`. Do NOT SSH-edit on the VM for non-emergency changes. The skill enforces clean-local + up-to-date-with-origin pre-flight + refuses to force-push.

## 2) Mandatory Preflight Before Any Edit

All edits happen in the **local clone** at `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol\`. Run these checks locally in order before coding:

```bash
# 1) Confirm cwd is the local clawtrol clone
pwd && git rev-parse --show-toplevel
# Expected: .../clawtrol  (NOT clawtrol-workspace, NOT clawdeck_remote_work)

# 2) Confirm origin matches the canonical repo
git remote get-url origin
# Expected: https://github.com/wolverin0/clawtrol.git

# 3) Confirm branch + dirty state + sync with origin
git branch --show-current
git status --short
git fetch origin && git status -uno   # see if behind/ahead

# 4) Confirm target file exists locally
ls -la <target_path>
```

If `pwd` does not end in `clawtrol` OR origin is not `wolverin0/clawtrol`, stop and re-route. Do NOT SSH to the VM to edit. Pre-deploy verification of the VM state is handled by the `/deploy-to-vm` skill, not the edit preflight.

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

1. Edit code in the local clone only (`G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol\`). Never SSH-edit `/home/ggorbalan/clawdeck` for non-emergency work — see `.claude/rules/local-first-workflow.md`.
2. Avoid broad refactors in dirty worktrees unless explicitly requested.
3. Never use destructive git commands (`reset --hard`, `checkout --`, force-push) unless asked.
4. When context is ambiguous, run the section 2 preflight before touching files.
5. Prefer small reversible changes with explicit validation steps.
6. Keep roadmap checkboxes updated in the same execution window.
7. Ship via `/deploy-to-vm`. Do not `git pull` directly on the VM as part of a normal change.

## 9) Common Pitfalls and Fixes

### Pitfall: "I changed files but app did not change"
Cause: either (a) edited the wrong folder (`clawtrol-workspace/`, `clawdeck_remote_work/`, or a `gitclones/` reference clone), or (b) edited locally but never deployed.
Fix:
- Re-run section 2 preflight; confirm `pwd` ends in `clawtrol` and origin is `wolverin0/clawtrol`.
- If the local change is committed but the VM is unchanged, run `/deploy-to-vm` to push + pull on VM + restart the service.

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
