# Curation Log — 2026-04-19

Curation of `clawtrol/.claude/` via the `project-curate` skill. Branch `omni/fix-claude-rules-curation`.

## Context before curation

- Stack: Rails 8.1 + Postgres + Solid Queue/Cache/Cable + Hotwire (Turbo + Stimulus) + Tailwind via tailwindcss-rails + Importmap (no Node at root) + Propshaft + Puma + dotenv-rails + OmniAuth (no Devise) + Sentry.
- Layout: standard Rails. `app/{models,views,controllers,javascript,services,assets}`, `config/`, `db/`, `test/` (Minitest). `app/components/` does NOT exist. Tailwind source CSS at `app/assets/tailwind/application.css`.
- Repo: full git clone of `wolverin0/clawtrol` on Windows. VM at `/home/ggorbalan/clawdeck` is pull-only (deploy target).
- Pre-existing `.claude/`: empty except for the `_backups/` tarball written by this skill on the prior pass. No mass-installed noise to archive.
- CLAUDE.md: missing. AGENTS.md: present (300+ lines, comprehensive but had stale SSH-edit references in sections 2/8/9 from the pre-2026-04-19 "Windows is a docs mirror" era).
- Memory: 0 prior MemoryMaster claims for `project:clawtrol` (added 3 during this session — see mm-3967, mm-31cb, mm-9169).

## What was copied from ECC

ECC has no `rules/ruby/` directory — no copy possible for the Rails stack. Only the web rules were applicable:

| ECC source | Local target | Frontmatter injected |
|---|---|---|
| `rules/web/design-quality.md` | `.claude/rules/web/design-quality.md` | `app/views/**/*.erb`, `app/assets/stylesheets/**/*.css` |
| `rules/web/performance.md` | `.claude/rules/web/performance.md` | `app/views/**/*.erb`, `app/javascript/**/*.js`, `app/assets/**/*.{js,css}`, `config/importmap.rb` |
| `rules/web/security.md` | `.claude/rules/web/security.md` | `app/**/*.{rb,erb,js,css}`, `config/**/*.{rb,yml}`, `lib/**/*.rb` |

The ECC web rules ship without `paths:` frontmatter; per the skill spec they were given Rails-flavored globs to scope load.

## What was generated (project-specific)

| File | Why | Source signals |
|---|---|---|
| `local-first-workflow.md` | The 2026-04-19 workflow pivot from SSH-edit-on-VM to local-clone + deploy-to-vm needed durable rules, not just AGENTS.md prose. | AGENTS.md section 1 update, the new `/deploy-to-vm` skill, repo topology |
| `rails-conventions.md` | No ECC `rules/ruby/` exists. Rails 8.1 has enough sharp edges (Hotwire vs custom JS, Propshaft vs Sprockets, Importmap vs Node, dotenv vs credentials, Solid Queue vs Sidekiq) to warrant a focused rule. | Gemfile, `config/`, `app/javascript/`, `app/assets/tailwind/` |

Two project-specific rules — well within the skill's 3-4 max budget.

## What was preserved untouched

- AGENTS.md: only the stale sections 2/8/9 were edited (local-first rewrite). Sections 1, 3-7, 10-12, BEADS integration, Landing the Plane — left intact.
- CLAUDE.md: didn't exist, was created from scratch as a minimal Claude-specific entry pointing to AGENTS.md + the auto-loaded rules table.
- `.claude/_backups/pre-curate-2026-04-19.tgz`: left in place, gitignored.

## What was archived

Nothing — no mass-install noise to archive. `.claude/_archive_noise_*` directory not created.

## What was NOT done and why

- **ECC ruby/ rules**: don't exist. Generated `rails-conventions.md` instead.
- **CI/CD project rule**: AGENTS.md section 7 already documents the merge gate baseline + `bin/ci` is referenced. A separate rule would duplicate.
- **Database/migration project rule**: covered inline in `rails-conventions.md` Migrations section. Stand-alone rule would split related context.
- **Testing project rule**: global `~/.claude/rules/testing.md` covers basics. Minitest specifics covered in `rails-conventions.md`.
- **Cherry-pick of ECC skills**: skipped per skill default ("user has 100+ globally; piling more on creates noise"). Only `deploy-to-vm` (a project-specific skill, not from ECC) is present.
- **Cherry-pick of ECC agents**: skipped per skill default.
- **Verifier pane**: skipped — coordinator-self-verify (Step 7b) used instead, which caught real drift (see below). Spawning a verifier pane for a 2-rule curation would be pure overhead.

## Verifier — coordinator self-verify

Grep-verified every backtick file/path/gem reference in the generated rules. Findings:

| Rule | Reference | Status | Fix |
|---|---|---|---|
| `rails-conventions.md` | `config/tailwind.config.js` | BROKEN — actual path is `app/assets/tailwind/application.css` (Tailwind v4 + tailwindcss-rails) | Rewrote Tailwind section with correct path + explicit "no `config/tailwind.config.js`" note |
| `rails-conventions.md` | `config/master.key`, `bin/rails credentials:edit` | BROKEN — project uses `dotenv-rails`, not Rails encrypted credentials. No `config/master.key` or `config/credentials.yml.enc` exists. | Rewrote Secrets section: dotenv-rails is canonical, `.env.production.example` is the template, NEVER attempt `credentials:edit` |
| `rails-conventions.md` | "Not sure if there's ActiveJob/Solid Queue usage yet" | DRIFT — `solid_queue` is in Gemfile, hedge was unnecessary | Tightened to "use it as the ActiveJob backend" + added `solid_cache`/`solid_cable` family note |
| `web/design-quality.md` | `app/components/**/*.{rb,erb}` glob | DEAD — `app/components/` doesn't exist (no ViewComponent gem); glob matches nothing | Removed the dead glob; kept `app/views/**/*.erb` + `app/assets/stylesheets/**/*.css` |
| `CLAUDE.md` | (table sync) | Out of date with the design-quality.md fix above | Updated the auto-loaded-rules table to drop the components glob |
| All other refs in all rules | (Gemfile gems, dirs, files) | VERIFIED | n/a |

Self-verify caught 4 distinct drifts. Fix is in the `fix(claude-rules):` amendment commit.

## Commits

- `c9020ce` chore(claude): curate .claude/ rules + skills for local-first workflow
- (next) fix(claude-rules): correct drifted identifiers caught by self-verify + add gitignore + curation log

## Next

User decides when to push `omni/fix-claude-rules-curation` and open the PR. The branch contains: AGENTS.md rewrite + new CLAUDE.md + `.claude/rules/` + `.claude/skills/deploy-to-vm/` + `.gitignore` update + this log.
