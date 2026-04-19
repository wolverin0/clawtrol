---
paths:
  - "app/**/*.{rb,erb}"
  - "config/**/*.{rb,yml}"
  - "db/migrate/**/*.rb"
  - "test/**/*.rb"
  - "Gemfile"
---

# Rails 8.1 Conventions — Clawtrol

Stack (per Gemfile): Rails 8.1, Propshaft, Postgres (`pg`), Puma, Importmap, Turbo, Stimulus, Tailwind CSS, Jbuilder. Ruby version pinned in `.ruby-version`.

## Hotwire-first

This app uses Hotwire (Turbo + Stimulus), not a JS framework. Before reaching for anything custom:

- **Turbo Drive** handles navigation. Don't replace with `fetch()` + DOM manipulation unless Turbo genuinely can't do it.
- **Turbo Frames** for scoped updates. A form inside `<turbo-frame id="x">` naturally replaces just that frame on submit.
- **Turbo Streams** for multi-region or server-pushed updates.
- **Stimulus controllers** for client-side behavior. Controllers live in `app/javascript/controllers/`. Name by file, auto-registered.

If you're writing a React component, stop and reconsider. The app's current trajectory is server-rendered + Hotwire. Breaking that is a scope decision, not a local choice.

## Propshaft, not Sprockets

Asset pipeline is **Propshaft**. Don't add `Sprockets` gems or `require_tree` directives. Static assets under `app/assets/` are served as-is with digest fingerprints. CSS is Tailwind + plain CSS; no SASS preprocessing unless explicitly added.

## Importmap, not Node

JavaScript is managed via **Importmap**, configured in `config/importmap.rb`. There's no `package.json` at the Rails root (any node_modules here would be a mistake). To add a JS library:

```bash
bin/importmap pin some-library
```

This edits `config/importmap.rb` and vendors the file. Do NOT `npm install` — you'd be fighting the tooling.

## Tailwind CSS

Tailwind via `tailwindcss-rails` gem. Source CSS lives at `app/assets/tailwind/application.css` (Tailwind v4 + tailwindcss-rails convention — there is NO `config/tailwind.config.js`). Rebuild happens on boot in dev; in prod the Dockerfile handles it. Don't inline style attributes when a Tailwind utility exists.

## Migrations

Rails 8.1 migrations: generate with `bin/rails g migration`. Always add a migration file — never hand-edit `db/schema.rb`. The schema file is regenerated from migrations. If you see schema.rb drift (like today's VM has `M db/schema.rb`), that's a smell — find the migration that should produce it or revert the drift.

## Tests

`test/` directory uses Minitest (Rails default). Run via `bin/rails test` or `bin/rails test:system` for system tests. Before deploying via `/deploy-to-vm`, tests must pass:

```bash
docker compose run --rm clawdeck bin/rails test
```

## ActiveRecord scope

- Queries scoped via named scopes in the model, not inline in controllers
- N+1 via `includes(:association)` in controller actions
- No raw SQL unless absolutely necessary — prefer Arel or parameterized AR

## Secrets / Credentials

This project uses **`dotenv-rails`**, not Rails encrypted credentials. There is NO `config/master.key` or `config/credentials.yml.enc` in this repo — don't try to `bin/rails credentials:edit`.

- Local dev/test secrets: `.env` files (gitignored). Template: `.env.production.example`.
- Production secrets: env vars on the VM, loaded by docker compose.
- Never commit `.env`. Never put secrets in source. If a secret needs to be added, update `.env.production.example` with a placeholder + document where the real value lives.

## Jobs + background work

`solid_queue` is in the Gemfile — use it as the ActiveJob backend. Don't add Sidekiq, Resque, or other queue gems unless there's a concrete reason Solid Queue can't handle the workload. Cache uses `solid_cache`, Action Cable uses `solid_cable` — same family, all Postgres-backed.

## Controllers thin, models fat

Standard Rails pattern. If a controller action is >10 lines of logic, that logic belongs in a model method, service object under `app/services/`, or interactor. Keep controllers to: params → call business logic → redirect/render.

## File naming

- Models: `snake_case.rb`, class `CamelCase`, file matches table name singular
- Controllers: `snake_case_controller.rb`, class `SnakeCaseController`, file matches resource plural
- Views: `.html.erb` for HTML, `.turbo_stream.erb` for streams, `.json.jbuilder` for API JSON
- Services (if under `app/services/`): `snake_case_service.rb`, class `SnakeCaseService`

## Don't

- Don't add `rack-cors` unless you're building an API. This app is not cross-origin.
- Don't add `devise` if Auth is already in place — check `app/models/user.rb` + `config/routes.rb` for the existing auth scheme first.
- Don't add Grape/Rails-API style controllers when Turbo Streams solve it. API-only controllers are for true JSON clients.
