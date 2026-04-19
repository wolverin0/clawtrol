---
name: deploy-to-vm
description: Deploy clawtrol changes to the Ubuntu VM (192.168.100.186) via git push → remote pull → optional docker restart → smoke check. Enforces safety rails (no uncommitted work, no out-of-sync branches, no surprise force-pushes). Use when ready to ship a change to the running instance at the VM.
argument-hint: "[--no-restart] [--skip-smoke] [--branch <name>] [--force-sync]"
trigger: /deploy-to-vm
---

# deploy-to-vm

Deploy local commits to the VM-hosted clawtrol instance.

## Target

- **VM:** 192.168.100.186 (Ubuntu)
- **User:** ggorbalan
- **SSH key:** `~/.ssh/id_rsa`
- **Remote repo path:** `~/clawdeck/` (folder named `clawdeck` historically; the upstream repo is `wolverin0/clawtrol`)
- **Service port:** 4001 (docker-compose maps container 3000 → host 4001)
- **DB:** Postgres, database `clawdeck_production`
- **Stack:** Rails 8.1 + Postgres + Docker Compose

## Flags

| Flag | Effect |
|------|--------|
| (none) | Full deploy: push → pull → restart → smoke-check |
| `--no-restart` | Skip docker compose restart (use when changes are docs-only) |
| `--skip-smoke` | Skip HTTP smoke check at port 4001 |
| `--branch <name>` | Deploy a specific branch instead of current |
| `--force-sync` | Allow deploy even if local has uncommitted changes (DANGEROUS — ask user first) |

## Non-negotiable pre-flight checks

Before any network operation:

1. **Local must be clean.**
   ```bash
   git status --porcelain
   ```
   If output is non-empty, STOP and report. Do NOT deploy dirty. Require `--force-sync` + user acknowledgment before proceeding.

2. **Local must be up-to-date with origin.**
   ```bash
   git fetch origin
   LOCAL=$(git rev-parse @)
   REMOTE=$(git rev-parse @{u})
   BASE=$(git merge-base @ @{u})
   ```
   - If `LOCAL == REMOTE`: in sync.
   - If `LOCAL == BASE` (remote ahead): STOP. Pull first.
   - If `REMOTE == BASE` (local ahead): OK to push.
   - Otherwise (divergent): STOP. Fix the divergence first.

3. **SSH connectivity works.**
   ```bash
   ssh -i ~/.ssh/id_rsa -o BatchMode=yes -o ConnectTimeout=8 ggorbalan@192.168.100.186 "echo ok"
   ```
   If this fails, report auth/network error. Don't continue.

4. **VM has no uncommitted changes that would be blown away.**
   ```bash
   ssh -i ~/.ssh/id_rsa ggorbalan@192.168.100.186 "cd ~/clawdeck && git status --porcelain"
   ```
   If non-empty, STOP. Show the diff to the user. The VM may have local config edits (like `db/schema.rb` drift from migrations) that shouldn't be overwritten. Require user confirmation before continuing.

## Deploy flow

### Step 1. Push

```bash
BRANCH=$(git branch --show-current)
git push origin "$BRANCH"
```

If the branch is new on origin, push with `-u`. If the push is rejected, do NOT force-push — surface the rejection and stop.

### Step 2. Remote fetch + checkout + pull

```bash
ssh -i ~/.ssh/id_rsa ggorbalan@192.168.100.186 "set -e
cd ~/clawdeck
git fetch origin
git checkout $BRANCH
git pull --ff-only origin $BRANCH"
```

`--ff-only` is mandatory. If the VM's HEAD is divergent, that's a flag — requires manual resolution, not automatic merge.

### Step 3. Restart services (unless `--no-restart`)

The app runs under Docker Compose on the VM. Detect the running compose project and restart:

```bash
ssh -i ~/.ssh/id_rsa ggorbalan@192.168.100.186 "set -e
cd ~/clawdeck
docker compose ps --services 2>&1 | head -5
docker compose restart clawdeck"
```

If migrations are needed, user triggers that explicitly — do NOT auto-migrate on deploy. Migrations are a separate workflow: `ssh … "cd ~/clawdeck && docker compose exec clawdeck bin/rails db:migrate"`.

### Step 4. Smoke check (unless `--skip-smoke`)

Wait 5 seconds for the service to come up, then:

```bash
curl -sSf -o /dev/null -w "HTTP %{http_code}\n" http://192.168.100.186:4001/ || {
  echo "SMOKE FAIL: service not responding on :4001"
  echo "Check logs: ssh ... 'cd ~/clawdeck && docker compose logs --tail 50 clawdeck'"
  exit 1
}
```

HTTP 200/301/302 = OK. Anything else = report and let user investigate.

### Step 5. Report

```
DEPLOYED: <branch> @ <short-sha>
  pushed:    $(git log origin/$BRANCH -1 --format='%h %s')
  VM pulled: <VM's new HEAD>
  restart:   ok (or skipped)
  smoke:     HTTP 200 (or the actual code)

Logs available at:
  ssh -i ~/.ssh/id_rsa ggorbalan@192.168.100.186 "cd ~/clawdeck && docker compose logs -f --tail 100"
```

## Rollback

The skill does NOT auto-rollback on smoke-fail — that's a decision for the user. Rollback pattern:

```bash
ssh -i ~/.ssh/id_rsa ggorbalan@192.168.100.186 "set -e
cd ~/clawdeck
git reset --hard HEAD@{1}
docker compose restart clawdeck"
```

`HEAD@{1}` is the previous state (before the most recent `pull`). If multiple pulls happened, bump the number.

## What this skill will NEVER do

- **Force-push** to origin.
- **Auto-run migrations.** Destructive to prod data if they fail mid-flight.
- **`rm`, `drop database`, `reset --hard` without explicit user request.**
- **Deploy through SSH if local is dirty** (unless `--force-sync` + user acknowledges).
- **Overwrite VM-local uncommitted changes.** Report + ask first.
- **Silently skip the smoke check.** If `--skip-smoke` is passed, it says so in the report. User owns the risk.

## When to use

Use after:
- `git commit` lands a local change you want in prod
- A PR merges to a branch the VM already tracks
- You've pulled from origin and want the VM to match

Don't use for:
- Schema migrations (run those as explicit one-off)
- Config changes requiring container rebuild (that's `docker compose build`, handle manually)
- Breaking changes without a rollback plan

## Known VM state (as of 2026-04-19)

- Branch: `docs/restore-runbook`
- HEAD: `b54b354` (same as local after clone)
- Has one uncommitted local change: `M db/schema.rb` — this is schema drift that predates this skill. Pre-flight check #4 will flag it on every deploy until resolved. Resolution path: either commit it on the VM and push to origin, or revert it locally on the VM if it's unwanted drift.

## Caveats

- **OneDrive latency:** this skill runs from a OneDrive-backed repo. Every `git fetch/push` touches OneDrive-synced `.git/` files. Expect slight operation slowness, not a correctness issue.
- **SSH BatchMode:** all SSH commands use `BatchMode=yes` to fail fast on auth issues rather than hang on password prompts. If your SSH key setup changes, these will fail loudly — that's intentional.
- **Branch naming:** local and remote `~/clawdeck/` on the VM track the same `origin`. The historical naming mismatch (local folder `clawdeck` vs upstream repo `clawtrol`) does not affect the deploy flow but can confuse people reading docs.
