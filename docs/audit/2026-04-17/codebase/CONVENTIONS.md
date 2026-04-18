# ClawTrol — Code Conventions

_Dated: 2026-04-17_

Canonical style and naming rules extracted from the live codebase. Rails 8.1, Ruby 3.3.1. Enforced by RuboCop (rubocop-rails-omakase) and reviewed in CI on every PR.

## Lint & Formatting

- **Linter:** `rubocop-rails-omakase` inherited from the gem, one project override.
- **Config:** `.rubocop.yml` (6 lines, shown in full below).
- **No `.editorconfig`** — rely on the omakase defaults.
- **No `.rubocop_todo.yml`** — codebase is clean against current rules.
- **CI job `lint`** runs `bin/rubocop -f github` with a RuboCop cache keyed on `.ruby-version`, `**/.rubocop.yml`, `Gemfile.lock`. Failures block merge.

```yaml
# .rubocop.yml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

# Disable array bracket spacing - codebase has mixed styles
Layout/SpaceInsideArrayLiteralBrackets:
  Enabled: false
```

- **`# frozen_string_literal: true`** is present at the top of every Ruby file in `app/`, `test/`, `config/` (checked across models, controllers, jobs, services, tests). Treat it as mandatory.
- **Double-quoted strings** are the house style (omakase default).
- **2-space indentation**, no tabs.

## File & Directory Layout

Standard Rails 8.1 tree. Additional conventions observed:

| Area | Rule | Example |
|---|---|---|
| API controllers | Namespaced under `Api::V1`, inherit from `Api::V1::BaseController` (an `ActionController::API` subclass) | `app/controllers/api/v1/tasks_controller.rb` |
| HTML controllers | Inherit from `ApplicationController` (full stack with cookies, auth, pagy) | `app/controllers/boards_controller.rb` |
| Admin | Lives under `app/controllers/admin/` with its own base controller | `app/controllers/admin/dashboard_controller.rb` |
| Model mixins | Split via `concern`-style modules under the model's own namespace | `app/models/task/broadcasting.rb`, `app/models/task/recurring.rb` |
| Cross-cutting concerns | `app/models/concerns/`, `app/controllers/concerns/`, `app/jobs/concerns/` | `ValidationCommandSafety`, `StatusConstants` |
| Services | Flat `app/services/*.rb`, plus nested `app/services/zerobitch/` for subdomain | `agent_completion_service.rb` |
| Jobs | Flat `app/jobs/*.rb`, inherit from `ApplicationJob` | `factory_runner_job.rb` |
| Serializers | `app/serializers/` (custom, not jsonapi) | — |
| Presenters | `app/presenters/` | — |

Task model in particular is split across multiple concerns that the main class includes in a fixed order:

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  include Task::Broadcasting
  include Task::Recurring
  include Task::TranscriptParsing
  include Task::DependencyManagement
  include Task::AgentIntegration
  include ValidationCommandSafety

  strict_loading :n_plus_one
  ...
end
```

When a model grows past ~400 lines, extract behaviour into a `Task::Thing` concern under `app/models/task/` rather than letting the file grow. Mirror this pattern for other large aggregates.

## Naming

| Kind | Convention | Example |
|---|---|---|
| Classes | `CamelCase` | `FactoryRunnerJob`, `AgentCompletionService` |
| Files | `snake_case.rb`, one top-level class per file | `agent_completion_service.rb` |
| Services | Suffix `Service` unless the domain noun already implies action | `AgentCompletionService`, `DeliveryTargetResolver` (no suffix when the name is already a noun-of-action) |
| Jobs | Suffix `Job` | `ZeroclawAuditorJob`, `ProcessRecurringTasksJob` |
| Controllers | Plural noun + `Controller` | `TasksController`, `BoardsController` |
| API controllers | Inside `Api::V1::` module, plural | `Api::V1::TasksController` |
| Tests | Mirror source path, suffix `_test.rb` | `test/services/zerobitch/metrics_store_test.rb` |
| Enums | `enum :name, { key: integer }, default:, prefix:` — always explicit integer values | `enum :priority, { none: 0, low: 1, medium: 2, high: 3 }, default: :none, prefix: true` |
| Constants | `SCREAMING_SNAKE_CASE`, `.freeze` | `MODELS`, `DEFAULT_MODEL`, `KANBAN_PER_COLUMN_ITEMS` |

## ActiveRecord Conventions

Observed across `app/models/task.rb` and peer models:

- **Always pass `inverse_of:`** on `has_many` / `belongs_to` associations. This is enforced by convention, not by a cop.
- **`counter_cache: true`** on hot counts (`belongs_to :board, counter_cache: true`).
- **`dependent:`** explicitly set on every `has_many` — `:destroy`, `:nullify`, or `:delete_all` chosen deliberately.
- **`strict_loading :n_plus_one`** on hot aggregates (Task) to force eager loading in callers. Bullet is the runtime backstop (see TESTING.md).
- **Explicit integer values in `enum`** — never rely on positional ordering; it lets us add statuses without renumbering.
- **`prefix: true`** on enums that could collide with Ruby methods (`priority_none?`, `priority_high?`).

## Error Handling

Two-tier strategy: rescue at the controller boundary, let lower layers raise.

**HTML controllers** (`ApplicationController`):

```ruby
rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
rescue_from ActiveRecord::StaleObjectError, with: :render_conflict
rescue_from ActionController::ParameterMissing, with: :render_bad_request
```

Each handler uses `respond_to` to serve HTML / JSON / Turbo-Stream variants.

**API controllers** (`Api::V1::BaseController`):

```ruby
rescue_from ActiveRecord::RecordNotFound,       with: :not_found
rescue_from ActiveRecord::RecordInvalid,        with: :unprocessable_entity
rescue_from ActiveRecord::StaleObjectError,     with: :conflict
rescue_from ActionController::ParameterMissing, with: :bad_request
rescue_from ArgumentError,                      with: :bad_argument
```

Bodies return `{ error: "..." }` JSON with the matching HTTP status.

**Background jobs** use narrow `rescue => e` blocks around external I/O, log via `Rails.logger`, and re-raise or retry per-job. No bare `rescue` anywhere — every rescue either names a class or binds `=> e`.

**Do NOT** sprinkle `begin/rescue` inside models or services for ordinary control flow. Let exceptions propagate to the controller / job boundary.

## Logging

- **205 `Rails.logger.*` call sites** across `app/`. Prefer `Rails.logger.info` / `.warn` / `.error` over `puts` or `print`.
- **Tag the source in brackets**: `Rails.logger.warn("[API] ArgumentError: #{exception.message}")` — the bracketed prefix (`[API]`, `[FactoryRunner]`, `[OpenClaw]`) groups logs from the same subsystem and is greppable in Kamal deploy logs.
- **No `puts` in production code paths.** System-test helpers use `puts` for failure screenshots only.

## Comments & TODOs

- **TODOs are rare and actionable.** Only one TODO found in all of `app/`:
  `app/jobs/run_debate_job.rb:16   # TODO: When implementing real debate:`
- No `# FIXME` or `# HACK` markers. Keep it that way — if you add one, open a corresponding task in ClawTrol itself rather than orphan it in the source.
- Prefer structural comments that explain *why*, not *what*. The `MODELS` and `OPENCLAW_MODEL_ALIASES` blocks in `Task` are the canonical examples.

## Security Baseline

- **No hardcoded secrets.** ENV vars read via `ENV.fetch` or Rails credentials. `dotenv-rails` loads `.env` in dev/test only.
- **`after_action :set_security_headers`** on `ApplicationController` — defense in depth against misconfigured nginx.
- **`allow_browser versions: :modern`** — drops very old browsers at the controller layer.
- **Brakeman + bundler-audit + importmap audit** gate every PR; see TESTING.md.

## bin/ Scripts

| Script | Purpose |
|---|---|
| `bin/ci` | Full CI suite (setup, rubocop, bundler-audit, importmap audit, brakeman, tests, system tests, seeds). Driven by `config/ci.rb`. |
| `bin/rubocop` | Thin wrapper that forces `--config .rubocop.yml` for reproducibility. |
| `bin/brakeman` | Brakeman runner. |
| `bin/bundler-audit` | Gem CVE scan. |
| `bin/rails`, `bin/rake` | Standard Rails stubs. |
| `bin/setup`, `bin/dev` | Dev bootstrap and foreman runner. |
| `bin/kamal`, `bin/thrust` | Deploy tooling. |

There is **no `bin/test`** — always invoke tests via `bin/rails test` (see TESTING.md).

## Git Hygiene

- `bin/commit-msg-hook` exists — conventional commit style (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) is the project norm.
- `bin/merge_gate` runs local checks before merge.
- Atomic commits, no `.env` / credentials / `master.key` in git.
