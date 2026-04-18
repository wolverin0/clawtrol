# ClawTrol — Testing

_Dated: 2026-04-17_

Testing is Rails Minitest + fixtures, run in parallel, gated by a four-job GitHub Actions workflow. There is no RSpec, no FactoryBot, and no coverage tool in the Gemfile — coverage is measured by test count and CI green status, not by percentage.

## Suite Shape

**301 `*_test.rb` files** (`find test -type f -name '*_test.rb' | wc -l`). Breakdown by directory:

| Dir | Count | What lives here |
|---|---|---|
| `test/controllers/` | 141 | HTML + API controller tests (Api::V1 under `test/controllers/api/v1/`) |
| `test/services/` | 89 | Service objects, including the `zerobitch/` subdomain |
| `test/models/` | 41 | ActiveRecord unit tests — validations, enums, scopes, concerns |
| `test/jobs/` | 19 | `ActiveJob::TestCase` with WebMock-stubbed external calls |
| `test/helpers/` | 3 | View helpers |
| `test/views/` | 3 | View-level assertions |
| `test/system/` | 2 | Capybara + headless Chrome end-to-end (`board_test.rb`, `swarm_test.rb`) |
| `test/integration/` | 2 | Full HTTP stack: `task_lifecycle_test.rb`, `security_test.rb` |
| `test/serializers/` | 1 | JSON serializer output |
| `test/mailers/` | 0 | Mailers are not under test today |

Fixtures live in `test/fixtures/*.yml` (users, tasks, boards, api_tokens, invite_codes, etc. — 20 YAML files) plus `test/fixtures/files/`.

## Test Helper

`test/test_helper.rb` pins the baseline behaviour for every test:

```ruby
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["HOOKS_TOKEN"] ||= "test_hooks_token"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
require_relative "test_helpers/session_test_helper"

Rails.application.config.hooks_token = ENV.fetch("HOOKS_TOKEN", "test_hooks_token")

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

Key rules baked in:

- **Parallelism** is `:number_of_processors` — tests must be isolation-safe. Use fresh records or scoped fixtures; never mutate shared global state without `teardown`.
- **`fixtures :all`** means every fixture YAML is loaded for every test. Prefer referencing `users(:one)`, `boards(:one)`, `tasks(:one)` over hand-building records.
- **WebMock** blocks all outbound net traffic by default, but **permits `localhost`** (for Solid Queue / Action Cable / any local dev-gateway calls). If a test needs to block localhost too, do it explicitly in `setup` and restore in `teardown`:

```ruby
# from test/jobs/factory_runner_job_test.rb
setup do
  WebMock.enable!
  WebMock.disable_net_connect!(allow_localhost: false)
end

teardown do
  WebMock.reset!
  WebMock.disable_net_connect!(allow_localhost: true)  # restore the global default
end
```

- **`HOOKS_TOKEN`** is pinned to `"test_hooks_token"` so hook-auth code paths are exercisable without credentials.

## Writing Tests

### Models — use fixtures, test validations, defaults, enums

```ruby
# test/models/task_test.rb
class TaskTest < ActiveSupport::TestCase
  test "valid with minimum attributes" do
    task = Task.new(name: "Test", board: boards(:one), user: users(:one))
    assert task.valid?
  end

  test "defaults to inbox status" do
    task = Task.create!(name: "Default status", board: boards(:one), user: users(:one))
    assert_equal "inbox", task.status
  end
end
```

### API controllers — integration-test style with a Bearer header

The `Api::V1` fixtures ship a known plaintext token whose digest matches the DB record:

```ruby
# test/controllers/api/v1/tasks_controller_test.rb
class Api::V1::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_token = api_tokens(:one)
    @task = tasks(:one)
    @auth_header = { "Authorization" => "Bearer test_token_one_abc123def456" }
  end

  test "returns unauthorized without token" do
    get api_v1_tasks_url
    assert_response :unauthorized
  end

  test "index returns user tasks" do
    get api_v1_tasks_url, headers: @auth_header
    assert_response :success
    assert_kind_of Array, response.parsed_body
  end
end
```

### Jobs — `ActiveJob::TestCase` + WebMock

Each job test isolates its network surface. See `test/jobs/factory_runner_job_test.rb` for the canonical pattern (setup/teardown WebMock, drive with `.perform_now`).

### Integration tests — full lifecycle through the router

`test/integration/task_lifecycle_test.rb` drives a task through every kanban status using real `post` / `patch` calls and the `sign_in_as(user)` helper from `ApplicationSystemTestCase`. Use this layer for flows that cross multiple controllers.

### System tests — Capybara + headless Chrome, rack_test fallback

`test/application_system_test_case.rb` probes for `google-chrome` / `chromium-browser` / `chromium`. If present, it drives Selenium headless (`1400x1400`, `--no-sandbox --disable-dev-shm-usage --disable-gpu`). If absent, it silently falls back to `:rack_test` (no JS) and prints a one-time warning. Failure auto-saves screenshots to `tmp/screenshots/` and CI uploads them as a `screenshots` artifact.

Helpers provided: `sign_in_as(user)`, `sign_in_via_cookie(user)`, `wait_for_turbo`, `wait_for_stimulus`.

## N+1 Guard (Bullet)

`bullet` is in the `:development, :test` group. It is **off in development by default** and **on in CI only**:

```ruby
# config/environments/test.rb
if ENV["CI"].present?
  config.after_initialize do
    Bullet.enable = true
    Bullet.raise = true   # N+1 = test failure
    Bullet.unused_eager_loading_enable = false
  end
end
```

Combined with `strict_loading :n_plus_one` on hot models (e.g. `Task`), this means **a N+1 query introduced in a PR fails the CI `test` job**. If you hit a Bullet error locally, add the missing `includes(...)` in the caller — do not silence the cop.

## Running Tests Locally

There is **no `bin/test`** script. Use Rails' own runners:

```bash
bin/rails test                          # everything under test/, excluding system
bin/rails test test/models              # a single directory
bin/rails test test/models/task_test.rb # a single file
bin/rails test test/models/task_test.rb:17  # a single line/test
bin/rails test:system                   # system tests only (needs Chrome)
bin/ci                                  # the full CI pipeline locally
```

`bin/ci` is driven by `config/ci.rb`:

```ruby
CI.run do
  step "Setup",                           "bin/setup --skip-server"
  step "Style: Ruby",                     "bin/rubocop"
  step "Security: Gem audit",             "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis","bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Rails",                    "bin/rails test"
  step "Tests: System",                   "bin/rails test:system"
  step "Tests: Seeds",                    "env RAILS_ENV=test bin/rails db:seed:replant"
end
```

## CI — `.github/workflows/ci.yml`

Four parallel jobs run on every PR and push to `main`:

| Job | Runs | Blocks merge on failure |
|---|---|---|
| `scan_ruby` | `bin/brakeman --no-pager` + `bin/bundler-audit` | yes |
| `scan_js` | `bin/importmap audit` | yes |
| `lint` | `bin/rubocop -f github` with RuboCop cache keyed on `.ruby-version`, `**/.rubocop.yml`, `Gemfile.lock` | yes |
| `test` | `bin/rails db:test:prepare test` against Postgres 16 service container | yes |
| `system-test` | `bin/rails db:test:prepare test:system` against Postgres 16, uploads `tmp/screenshots/` on failure | yes |

Test jobs use `postgres:16` as a service with `clawdeck_test` DB, `postgres/postgres` creds, and the standard `pg_isready` healthcheck. `DATABASE_URL` is injected as `postgres://postgres:postgres@localhost:5432/clawdeck_test`.

## Coverage

- **No SimpleCov**, no coverage gem. Coverage is not quantified.
- "Coverage" is measured by a) the 301-file test count, b) the four green CI gates, c) the `needs coverage` placeholder tests in newer `app/services/zerobitch/` specs (`test "needs coverage" do`) — these are intentional TODO markers, not real assertions.
- If/when we need a number, add `simplecov` to the `:test` group and report via `COVERAGE=1 bin/rails test`.

## What NOT to Do

- Do not add RSpec — the suite is 100% Minitest; mixing frameworks doubles the CI budget.
- Do not add FactoryBot — fixtures are the canonical seeding mechanism.
- Do not disable WebMock globally in a test. Scope it to `setup`/`teardown`.
- Do not rely on test ordering; parallelism reshuffles per run.
- Do not commit a test that depends on network. If you need an external HTTP shape, stub it with WebMock.
- Do not silence Bullet or RuboCop — fix the underlying issue, or discuss adding a targeted `.rubocop.yml` override.
