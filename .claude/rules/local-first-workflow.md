# Local-First Workflow — Clawtrol

As of 2026-04-19, clawtrol development happens in the **local git clone** at `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol\`, not via SSH-edit-on-VM. The VM runs the deployed version; it pulls from github, we push to github, the deploy skill orchestrates.

## Golden rule

**Edit locally. Deploy via `/deploy-to-vm`. Never SSH-edit files on the VM for non-emergency work.**

## The topology

- **Local (this dir):** full git clone of `https://github.com/wolverin0/clawtrol.git`. Same remote as the VM. Edits, commits, tests all happen here.
- **VM `~/clawdeck/`:** running Rails service. Pulled from origin. Treat as read-only except when debugging.
- **GitHub `wolverin0/clawtrol`:** source of truth. Both local and VM track it.

## Daily flow

1. `cd clawtrol` (local)
2. Create/checkout a working branch
3. Edit, run tests locally (`docker compose up`, `bin/rails test`, etc.)
4. Commit atomically
5. When ready to ship: `/deploy-to-vm` — the skill pushes to origin + pulls on VM + optionally restarts + smoke-checks

## What NOT to do

- **Never** SSH to the VM and `git commit` directly in `~/clawdeck/`. The VM working copy is deployment-only. If the VM has drift (like today's `M db/schema.rb`), resolve it by either committing & pushing upstream OR reverting — not by building on it.
- **Never** skip the `/deploy-to-vm` pre-flight checks. They catch dirty-local, out-of-sync, VM-has-uncommitted-drift before network operations.
- **Never** force-push. Destructive to team history and the VM deploy flow.
- **Never** edit `docker-compose.yml` / `Dockerfile` on the VM only. Container changes need to go through git → deploy.

## When SSH-to-VM IS appropriate

Debugging-only, read-only, or one-off:

- Tailing logs: `ssh ggorbalan@192.168.100.186 "cd ~/clawdeck && docker compose logs -f clawdeck"`
- Checking service state: `docker compose ps`, `systemctl --user status clawdeck-web.service`
- Running a one-off console: `docker compose exec clawdeck bin/rails console`
- Inspecting DB: `docker compose exec db psql -U postgres clawdeck_production`

If you catch yourself `vim`ing a file on the VM, STOP. Do it locally and deploy.

## The audit workspace

`G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol-workspace\` holds the audit docs that used to live at this repo root before the 2026-04-19 re-clone (AUDIT.md, FIX_PROMPTS.md, FEATURE_IDEAS.md, roadmap.md, obsidian-vault/, screenshots). They're planning artifacts ABOUT the system, not part of the repo. Reference them as needed; commit new planning docs under `docs/` in this repo instead.

## If you're confused about which path to edit

Check by running `pwd && git remote get-url origin` in your current shell. If you see `G:\_OneDrive\...\clawtrol` AND `https://github.com/wolverin0/clawtrol.git`, you're in the right place.
