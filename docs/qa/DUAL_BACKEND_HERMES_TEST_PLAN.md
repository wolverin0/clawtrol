# SUPERSEDED — Dual Backend Hermes Test Plan
<!-- Historical direct-control test plan; dual/Hermes execution modes are retired. -->
<!-- Key terms: SUPERSEDED, passive mirror, no direct Hermes control, no dual mode. -->
<!-- Read docs/DOCS-MAP.md and docs/reports/hermes-delta-review-2026-07-26.md first. -->
<!-- Replaced by dedicated passive-mirror endpoint, sidecar, schema, and boundary tests. -->
<!-- Do not restore adapters, CLI subprocesses, gateway credentials, or token-valued forms. -->
<!-- Status updated: 2026-07-26 safe-LAN remediation. -->

## Scope
Validate ClawTrol's OpenClaw + Hermes dual-backend MVP: user platform configuration, adapter registry/CLI behavior, file viewer logical roots, migrations, Docker images, and live HTTP smoke paths.

## Automated verification
Run from the repository root.

### 1. Ruby syntax
```bash
ruby -c app/models/user.rb
ruby -c app/controllers/file_viewer_controller.rb
for f in app/services/agent_platforms/*.rb test/services/agent_platforms/*.rb test/controllers/file_viewer_controller_test.rb test/models/user_test.rb db/migrate/*add_agent_platform_fields_to_users.rb; do ruby -c "$f"; done
```

### 2. Production image build
```bash
docker compose build clawdeck
```
Expected: image builds and assets precompile successfully.

### 3. Test-capable image build
```bash
docker build --build-arg BUNDLE_WITHOUT='' -t clawdeck-test .
```
Expected: test/development gems are included so Rails tests can boot in Ruby 3.3.8.

### 4. Focused regression tests
```bash
docker compose up -d db
docker run --rm --network clawdeck_clawdeck-network --entrypoint bash \
  -e RAILS_ENV=test -e SECRET_KEY_BASE=dummy -e HOOKS_TOKEN=test_hooks_token \
  -e CLAWTROLPLAYGROUND_DB_USERNAME=postgres \
  -e CLAWTROLPLAYGROUND_DB_PASSWORD=postgres \
  -e CLAWTROLPLAYGROUND_DB_HOST=db \
  -e CLAWTROLPLAYGROUND_TEST_DB_NAME=clawdeck_test \
  clawdeck-test -lc 'bundle exec rails db:prepare && bundle exec rails test test/models/user_test.rb test/services/agent_platforms/registry_test.rb test/services/agent_platforms/hermes_cli_runner_test.rb test/controllers/file_viewer_controller_test.rb test/controllers/profiles_controller_test.rb'
```
Expected: all focused tests pass.

### 5. Full Rails test suite
```bash
docker run --rm --network clawdeck_clawdeck-network --entrypoint bash \
  -e RAILS_ENV=test -e SECRET_KEY_BASE=dummy -e HOOKS_TOKEN=test_hooks_token \
  -e CLAWTROLPLAYGROUND_DB_USERNAME=postgres \
  -e CLAWTROLPLAYGROUND_DB_PASSWORD=postgres \
  -e CLAWTROLPLAYGROUND_DB_HOST=db \
  -e CLAWTROLPLAYGROUND_TEST_DB_NAME=clawdeck_test \
  -v "$PWD/.git:/app/.git:ro" \
  clawdeck-test -lc 'bundle exec rails db:prepare && bundle exec rails test'
```
Expected: suite passes. The `.git` mount is required because `.dockerignore` intentionally excludes git metadata from application images, while several existing tests validate git-aware services.

### 6. RuboCop touched Ruby files
```bash
docker run --rm --entrypoint bash -e RAILS_ENV=test -e SECRET_KEY_BASE=dummy clawdeck-test -lc 'bundle exec rubocop app/models/user.rb app/controllers/file_viewer_controller.rb app/controllers/profiles_controller.rb app/services/agent_platforms test/services/agent_platforms test/controllers/file_viewer_controller_test.rb test/controllers/profiles_controller_test.rb test/models/user_test.rb db/migrate/*add_agent_platform_fields_to_users.rb'
```
Expected: no offenses on touched Ruby files.

## E2E smoke verification

### 1. Migration and adapter smoke in production environment
```bash
docker compose up -d db
docker compose run --rm -e SECRET_KEY_BASE=dummy -e DATABASE_URL=postgresql://postgres:postgres@db:5432/clawdeck_production clawdeck bundle exec rails db:migrate
docker compose run --rm -e SECRET_KEY_BASE=dummy -e DATABASE_URL=postgresql://postgres:postgres@db:5432/clawdeck_production clawdeck bundle exec rails runner 'user = User.new(email_address: "dual@example.test", password: "password123", preferred_agent_platform: "hermes", orchestration_mode: "dual"); puts({valid: user.valid?, mode: user.orchestration_mode, platform: user.preferred_agent_platform, roots: FileViewerController::LOGICAL_ROOTS.keys}.inspect)'
```
Expected: user is valid, mode is `dual`, platform is `hermes`, and viewer roots include `hermes`.

### 2. Live web service smoke
```bash
docker compose up -d clawdeck
python3 - <<'PY'
from urllib.request import urlopen
for path in ['/up', '/view?file=hermes/test-plan-smoke.txt']:
    r = urlopen('http://127.0.0.1:4001' + path, timeout=10)
    print(path, r.status)
PY
```
Expected: `/up` returns 200. The Hermes viewer path should render the test artifact when present under the dedicated viewer root (`HERMES_VIEWER_DIR`, default `~/.hermes/artifacts/test-plan-smoke.txt`), or a safe not-found response if absent.

## Manual acceptance checklist
- Sign in as an admin/test user.
- Confirm OpenClaw-only users still resolve OpenClaw settings by default.
- Change a test user to `preferred_agent_platform=hermes` and `orchestration_mode=dual`; save succeeds.
- Visit `/view?file=openclaw/<known-file>` and verify legacy root behavior.
- Visit `/view?file=hermes/<known-file>` and verify it resolves under the dedicated Hermes viewer artifact root (`HERMES_VIEWER_DIR`, default `~/.hermes/artifacts`).
- Verify `/view?file=hermes/<config-file-under-raw-home>` is not served from raw `~/.hermes`.
- Verify `PUT /view?file=hermes/<known-file>` is rejected; Hermes viewer artifacts are read-only from ClawDeck.
- Try traversal attempts like `/view?file=hermes/../../etc/passwd`; verify it is blocked/not served.
- Stop or omit Hermes CLI and verify the Hermes adapter returns a structured offline/unsupported result instead of raising.

## Rollback notes
- Revert the commit if adapters or viewer roots regress.
- Database rollback removes Hermes user fields via `rails db:rollback STEP=1` for the migration `20260521120000_add_agent_platform_fields_to_users`.
