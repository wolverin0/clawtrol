# CLAUDE.md — ClawTrol (Claude-specific entry point)

**Canonical workflow lives in `AGENTS.md`.** Read it before any non-trivial change. This file only adds Claude Code–specific guidance not covered there.

## Where to write

- **Edit here** (local clone): `G:\_OneDrive\OneDrive\Desktop\Py Apps\clawtrol\`
- Never SSH-edit `/home/ggorbalan/clawdeck` for non-emergency work — see `.claude/rules/local-first-workflow.md`.
- Deploy with the `/deploy-to-vm` skill at `.claude/skills/deploy-to-vm/`.

## Auto-loaded rules

These load automatically based on the files you touch:

| Rule | Triggers on |
|---|---|
| `.claude/rules/local-first-workflow.md` | Always (no path filter) |
| `.claude/rules/rails-conventions.md` | `app/`, `config/`, `db/migrate/`, `test/`, `Gemfile` |
| `.claude/rules/web/design-quality.md` | `app/views/**/*.erb`, `app/assets/stylesheets/**/*.css` |
| `.claude/rules/web/performance.md` | `app/views/**/*.erb`, `app/javascript/**/*.js`, `app/assets/**/*.{js,css}`, `config/importmap.rb` |
| `.claude/rules/web/security.md` | `app/**/*.{rb,erb,js,css}`, `config/**/*.{rb,yml}`, `lib/**/*.rb` |

Plus the always-loaded global rules in `~/.claude/rules/` (coding-style, git-workflow, security, testing).

## Verification

Before claiming any work done, run the relevant subset of section 6 of `AGENTS.md`:
- Touched Ruby? → `bin/rubocop` + `bin/rails test`
- Touched ERB/JS/CSS? → load the page locally (`bin/dev`) and confirm visually
- Touched migrations? → `bin/rails db:migrate` on a clean local DB
- Pre-deploy? → `bin/ci`
