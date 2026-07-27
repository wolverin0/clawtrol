# ClawTrol recovery audit — 2026-07-26
<!-- Covers: recovery branch security and technical due diligence. -->
<!-- Key terms: hard stop, committed credential, same-origin untrusted HTML, Rails 8.1. -->
<!-- Read when deciding whether recovery/live-container-20260726 may be integrated or deployed. -->
<!-- Scope: repository evidence at 909e992; runtime/provider state is explicitly separated. -->
<!-- Verdict: DO NOT LAUNCH UNTIL HARD STOPS RESOLVED. -->
<!-- Status: complete repository audit; runtime/browser/provider revalidation remains separate. -->

Audited: `G:/_OneDrive/OneDrive/Desktop/Py Apps/clawtrol`

Stack: Ruby 3.3 / Rails 8.1 / PostgreSQL / Active Record / Hotwire / Solid Queue

Audit date: 2026-07-26

Baseline: `bbb75510de0d3ebd9c3efbfea7040c010c46c938`

Audited HEAD: `909e992a2e384aaea59b4f8d77b8eb3ef05cb5ba`

Inventory: 388 Rails route declarations; 171 migrations; 96 referenced environment variables; 9 feature-flag candidates; 303 tests; approximately 102,792 source lines. Full commands and limitations are in `.battle-test/20260726-204255/inventory.json`.

## HARD STOPS

Two hard-stop conditions are present.

### H4 — Secret committed in source and Git history: FOUND

`app/jobs/nightshift_runner_job.rb:43-47` embeds the shared hook credential in every generated mission prompt. `app/controllers/concerns/api/hook_authentication.rb:12-18` accepts the same credential class as authentication. A redacted full-history Gitleaks scan found the credential-bearing source in commit history; the working-tree scan also finds the active source occurrence.

Severity: Critical
Exploitability: EXPLOITABLE-NOW
Action: revoke and rotate immediately; remove it from source, prompts, logs, transcripts, and Git history; replace the global shared token with scoped, expiring service credentials.

### H6 — Untrusted HTML rendered on the authenticated app origin: FOUND

`app/controllers/marketing_controller.rb:39` exposes the marketing file viewer anonymously, while `app/controllers/marketing_controller.rb:213-220` renders workspace HTML with `html_safe`. Authenticated output routes repeat the pattern at `app/controllers/previews_controller.rb:53-59` and `app/controllers/showcases_controller.rb:23-37`. The iframe combines script execution with same-origin access at `app/views/previews/show.html.erb:54-58`.

Severity: Critical
Exploitability: EXPLOITABLE-LOW-EFFORT
Action: move untrusted artifacts to a separate cookieless origin with a restrictive CSP; never combine `allow-scripts` and `allow-same-origin`; sanitize or download workspace HTML.

### Remaining hard-stop checks

- H1 — Row-level access control: NOT FOUND from repository evidence. PostgreSQL is server-only and browser/API access is enforced in Rails; production DB grants were not queried.
- H2 — Admin/service secrets reachable from the client: NOT FOUND.
- H3 — Unauthenticated data-mutation endpoint: NOT FOUND. Browser controllers inherit `ApplicationController` authentication; 27 API controllers inherit token/session authentication; hook/cron exceptions use the hook-token concern.
- H5 — Inbound webhook without caller verification: NOT FOUND. The five hook routes use `Api::HookAuthentication`; cron-facing Nightshift exceptions install the same check before their actions.
- H7 — SQL injection: NOT FOUND. Dynamic database-administration SQL at `app/models/factory_loop.rb:230-301` quotes literals and identifiers before interpolation.
- H8 — Hardcoded admin/temp auth bypass: NOT FOUND. The unused configured admin email is not consulted by `authenticate_admin`; authorization uses the persisted `admin?` flag.
- H9 — Critical-flow tests that only assert mocks: NOT FOUND. Hook, session, token, password, and lifecycle paths have controller/integration/database tests.
- H10 — Unbounded paid endpoint: NOT FOUND as a hard stop. Image generation is authenticated and Rack::Attack supplies a limiter, although cost controls still need domain review.
- H11 — Paid API secret shipped to the browser: NOT FOUND.

## AUDIT VERDICT

🛑 DO NOT LAUNCH UNTIL HARD STOPS RESOLVED

This verdict is mechanically locked by H4 and H6. It does not mean the recovered baseline is unusable; it means the branch must not be integrated or deployed until credential rotation/removal and untrusted-content origin isolation have both been reverified.

## SEVERITY CENSUS — checkpoint

- Hard stops: 2
- Critical: 2
- High: 15
- Medium: 19
- Low: 0
- EXPLOITABLE-NOW: 2
- EXPLOITABLE-LOW-EFFORT: 4
- BAD-PRACTICE: 24
- UNKNOWN: 6

The census includes all 13 completed domains. Findings that describe a distinct architectural or integrity dimension of the same underlying hard stop remain visible in their domain.

Tambon density is not reported: the repository has no configured Ruby type checker, and the Tambon skill forbids fabricating density from grep alone. The stack-appropriate linter command inspected 864 files with zero offenses.

## TAMBON AND BLIND-SPOT WALK

Tambon static-analysis result: UNABLE to compute density because no Ruby type checker is configured. RuboCop parsed and inspected 864 files with zero offenses. No Hallucinated Object, Wrong Attribute, or Silly Mistake count is asserted from grep alone.

The B1-B19 walk found these confirmed patterns:

- B2 (failure represented as success): PRESENT — Factory ignores non-success wake responses (`app/jobs/factory_runner_job.rb:54-79`).
- B11 (missing idempotency/reconciliation): PRESENT — outbound wake/retry paths lack durable operation IDs (`app/services/openclaw_webhook_service.rb:81-109`, `app/jobs/nightshift_runner_job.rb:62-71`).
- B14 (comment-code drift): PRESENT — duplicated comments falsely describe `allow-scripts allow-same-origin` as a security boundary (`app/controllers/previews_controller.rb:53-59`, `app/controllers/showcases_controller.rb:23-37`).
- B16 (heavy work in request cycle): PRESENT — Docker execution can block a request for 125 seconds (`app/controllers/zerobitch_controller.rb:418-428`).
- B18 (non-idempotent action): PRESENT — Factory/OpenClaw launch paths have no stable request/delivery identity (`app/controllers/factory_controller.rb:98-101`, `app/jobs/factory_runner_job.rb:47-79`).

B1, B3, B4, B6, B10, B12, and B13 were not present in the directly inspected critical paths. B5, B7-B9, B15, B17, and B19 remain INCONCLUSIVE outside the directly inspected samples; they were not silently marked clean.

## STRENGTHS TO PRESERVE

- Browser sessions use signed, `HttpOnly`, strict-same-site cookies and destroy the server-side session on logout (`app/controllers/concerns/authentication.rb:53-79`).
- API bearer tokens are authenticated centrally before API actions (`app/controllers/api/v1/base_controller.rb:9-13`, `app/controllers/concerns/api/token_authentication.rb:9-30`).
- User-owned Nightshift read/write actions scope records through `current_user` (`app/controllers/api/v1/nightshift_controller.rb:17-75`, `app/controllers/api/v1/nightshift_controller.rb:198-220`).
- Dynamic SQL in Factory database setup quotes both values and identifiers (`app/models/factory_loop.rb:279-301`).

## REMEDIATION PLAN — checkpoint

M0 — Preserve the recovery backup, isolated DB restore proof, and passing 2,567-test baseline before changing security-critical paths: 0.5-1 developer-day.

Phase 0 — Hard stops: 2-4 developer-days.

1. Rotate the exposed hook credential and replace source/prompt interpolation with a scoped secret reference.
2. Scrub the credential from Git history and any generated prompt/transcript artifacts.
3. Isolate all agent/workspace HTML on a cookieless origin; add CSP and browser regression tests.
4. Prove the old credential receives 401 and malicious artifact JavaScript cannot access ClawTrol session state or authenticated endpoints.

Phase 3 — Known High findings: 1-2 developer-days.

1. Terminate TLS, enable Rails SSL assumptions/redirect/HSTS, and verify secure cookies.
2. Replace broad address safelisting with exact service-route plus service-identity exemptions.

Phase 1 — Other EXPLOITABLE-NOW/LOW-EFFORT cost and credential controls: 1-2 developer-days.

Phase 2/3 — Remaining Critical/High findings: 5-9 developer-days.

Phase 4 — Medium findings and regression coverage: 3-6 developer-days.

Estimated repository remediation total: 11.5-22 developer-days, including the safety net and hard stops. Add approximately 20% test-rewrite tax around the skip-only preview/showcase security tests. No duplication multiplier was applied.

## DOMAIN 1: SECURITY

### Founder view

Authentication is centrally wired and several important ownership checks are sound. Two concrete launch blockers override that baseline: a credential is committed and propagated into agent prompts, and agent-controlled HTML runs with the application's origin privileges. Transport and rate-limit trust configuration add two High risks.

### Technical evidence

#### F-1.1 — Active shared hook credential committed in code/history

Severity: Critical
Exploitability: EXPLOITABLE-NOW
Hard-stop: H4

Evidence: `app/jobs/nightshift_runner_job.rb:43-47`; `app/controllers/concerns/api/hook_authentication.rb:12-18`.

Fix and verification: rotate, remove, scrub, and replace with scoped credentials. A full-history secret scan must return no active match; the old credential must receive 401.

#### F-1.2 — Agent/workspace HTML executes under the application origin

Severity: Critical
Exploitability: EXPLOITABLE-LOW-EFFORT
Hard-stop: H6

Evidence: `app/controllers/marketing_controller.rb:39`, `app/controllers/marketing_controller.rb:213-220`, `app/controllers/previews_controller.rb:53-59`, `app/controllers/showcases_controller.rb:23-37`, `app/views/previews/show.html.erb:33-38`, `app/views/previews/show.html.erb:54-58`.

Fix and verification: serve from a separate cookieless origin with restrictive CSP. A malicious fixture must be unable to read parent DOM, cookie/CSRF state, or authenticated routes.

#### F-1.3 — Production explicitly disables HTTPS and HSTS

Severity: High
Exploitability: UNKNOWN

Evidence: `config/environments/production.rb:27-31`.

Fix and verification: terminate TLS, configure trusted proxy headers, enable `assume_ssl` and `force_ssl`, and verify HTTP redirects, HSTS, Secure cookies, and a valid TLS chain.

#### F-1.4 — Broad internal safelist can bypass Rack::Attack throttles

Severity: High
Exploitability: UNKNOWN

Evidence: `config/initializers/rack_attack.rb:11-17` safelists missing, loopback, and an entire private subnet before the throttles at `config/initializers/rack_attack.rb:27-64`.

Fix and verification: scope exemptions to exact service endpoints with authenticated service identity; correctly configure trusted proxies; test that proxy-presented external traffic is throttled.

Completeness: 27 API base descendants, standalone hooks, 10 authentication exceptions, 31 token/session source files, 9 browser-storage files, 55 secret-reading files, and all 388 route declarations were inventory-scanned. Twenty-five security-critical files were manually read.

[SECTION COMPLETE: Domain 1]

## DOMAIN 2: ARCHITECTURE

### Founder view

The recovered application works through several oversized boundary classes. Task completion, task API behavior, and the marketing studio each combine transport, persistence, orchestration, filesystem work, and presentation, so changes in these areas have a wide regression radius.

### Technical evidence

#### F-2.1 — Agent-completion webhook is a mixed transport/domain/filesystem transaction

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/api/v1/hooks_controller.rb:18-65`, `app/controllers/api/v1/hooks_controller.rb:406-455`, `app/controllers/api/v1/hooks_controller.rb:483-525`.

Fix and verification: introduce a transactional `AgentCompletionService` with explicit best-effort adapters for transcript/archive/message work. Verify idempotent completion, missing/copy-failed transcripts, rate-limit detection, pipeline failure, and retries with the hook controller tests.

#### F-2.2 — Tasks API controller is a 1,068-line multipurpose subsystem

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/api/v1/tasks_controller.rb:459-533`, `app/controllers/api/v1/tasks_controller.rb:746-860`, `app/controllers/api/v1/tasks_controller.rb:990-1049`.

Fix and verification: split file, review, dispatch, and import/export use cases behind named application services while preserving route contracts. Remove or feature-gate the random context-usage simulation at lines 1040-1049. Run the API controller and service suites.

#### F-2.3 — Marketing playground Stimulus controller combines an entire client application

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/javascript/controllers/playground_controller.js:49-108`, `app/javascript/controllers/playground_controller.js:332-384`, `app/javascript/controllers/playground_controller.js:622-706`, `app/javascript/controllers/playground_controller.js:837-951`.

Fix and verification: extract API, storage, filtering, gallery, and publishing modules plus nested controllers. Add unit tests for pure modules and a system flow for generate, compose, persist/reload, and queue.

Completeness: inventory covered 121 controller classes and 672 controller method candidates; the highest-risk and largest boundaries were directly inspected. Confidence is Medium because not every handler received line-by-line architectural classification.

[SECTION COMPLETE: Domain 2]

## DOMAIN 3: DATABASE

### Founder view

The audited schema generally uses foreign keys, but one optional board relationship is enforced only by Rails. Database-level writes or concurrent board deletion can leave orphaned Swarm ideas.

### Technical evidence

#### F-3.1 — `swarm_ideas.board_id` lacks a foreign key

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/models/swarm_idea.rb:33` declares the optional association; `db/schema.rb:864` stores `board_id`; the complete foreign-key section at `db/schema.rb:1263` includes only the Swarm idea user foreign key.

Fix and verification: repair existing orphans, add `swarm_ideas.board_id → boards.id` with `on_delete: :nullify`, inspect `connection.foreign_keys(:swarm_ideas)`, and assert an invalid board ID fails.

Completeness: the full schema foreign-key and `_id` surfaces, model associations, transactions/locks, multi-write hotspots, and SQL/RLS patterns were scanned. Production policies/data and every migration body were not individually inspected.

[SECTION COMPLETE: Domain 3]

## DOMAIN 4: DEVOPS

### Founder view

CI exists, but its Brakeman configuration hides scanner/parser failures. The documented VM deployment restarts an existing container without rebuilding the image, so a deploy can report success while serving old code.

### Technical evidence

#### F-4.1 — Deploy flow does not put new code into the running image

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `.claude/skills/deploy-to-vm/SKILL.md:77-98` pulls then restarts; `Dockerfile:38-44` and `Dockerfile:85-86` copy/build code only during image construction; `.claude/skills/deploy-to-vm/SKILL.md:102-114` verifies availability but not SHA.

Fix and verification: build and replace the service container, then verify a runtime version/SHA matches the deployed commit.

#### F-4.2 — Hosted CI suppresses Brakeman operational/parser failures

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `.github/workflows/ci.yml:21-26` uses `--no-exit-on-error`; `config/ci.rb:10` correctly enables exit on both warnings and errors.

Fix and verification: remove the broad suppression, narrowly resolve/exclude the known parser-incompatible template, and prove a parser failure makes hosted CI fail.

#### F-4.3 — Compose hardcodes an administrator database credential

Severity: Medium
Exploitability: EXPLOITABLE-LOW-EFFORT

Evidence: `docker-compose.yml:7-9`, `docker-compose.yml:36-39`, `docker-compose.yml:20-21`, `docker-compose.yml:45-46`.

Fix and verification: require external secrets, fail closed when absent, and use a least-privilege application role. Rendered Compose config must contain no literal password.

Completeness: 17 DevOps-relevant files were read; application/business files were out of this domain's scope.

[SECTION COMPLETE: Domain 4]

## DOMAIN 5: PERFORMANCE

### Founder view

Several request paths do too much synchronous work for Puma's three-thread default. The ZeroBitch assignment path can block every web thread, and two list screens scale query/render work directly with backlog size.

### Technical evidence

#### F-5.1 — Synchronous 125-second Docker execution can exhaust Puma

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/zerobitch_controller.rb:418-428`, `app/services/zerobitch/docker_service.rb:143-154`, `config/puma.rb:28-29`.

Fix and verification: enqueue the Docker task and return 202 with a run ID. Three concurrent requests should return within 500 ms while `/up` stays responsive.

#### F-5.2 — Admin user page performs per-row aggregate queries

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/admin/users_controller.rb:9-20` paginates 25 users then calls two aggregate queries for every user.

Fix and verification: use grouped aggregates/subqueries or counter caches; instrument SQL and assert query count stays constant as page size grows.

#### F-5.3 — Decision queue is unbounded and fully rerendered after every action

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/decisions_controller.rb:6-8`, `app/views/decisions/index.html.erb:4-8`, `app/views/decisions/update.turbo_stream.erb:5-9`.

Fix and verification: paginate/cursor the queue, remove only the resolved row, and update a separately queried count. With 500 tasks, response size should remain approximately constant.

Completeness: 434 DB/API matches, 57 cache matches, and 102 blocking/singleton candidates were inventory-scanned; eight high-priority files were directly read.

[SECTION COMPLETE: Domain 5]

## DOMAIN 6: UX AND ACCESSIBILITY

### Founder view

Several dynamically generated primary controls are mouse-only or unnamed. Keyboard and assistive-technology users cannot reliably operate parts of Factory, Cron Jobs, model status, tag removal, and the file editor.

### Technical evidence

#### F-6.1 — Core actions are pointer-only non-semantic elements

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/javascript/controllers/factory_controller.js:105`, `app/javascript/controllers/cronjobs_controller.js:289`, `app/javascript/controllers/model_status_controller.js:75`.

Fix and verification: use native buttons, or supply role/tabindex/name/keyboard state. Tab and activate each control with Enter and Space in system tests.

#### F-6.2 — Dynamic tag-removal button has no accessible name

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/javascript/controllers/auto_claim_tags_controller.js:35`.

Fix and verification: label it with the tag value and hide the decorative SVG from the accessibility tree.

#### F-6.3 — Dynamic file editor lacks a label

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/javascript/controllers/board_files_modal_controller.js:94`.

Fix and verification: associate the textarea with the visible filename and assert its accessible name in a browser accessibility tree.

Completeness: 339 frontend files were inventoried; five high-signal controllers were read. State, contrast, and 320px coverage was not exhaustive.

[SECTION COMPLETE: Domain 6]

## DOMAIN 7: RELIABILITY

### Founder view

Three outbound orchestration paths can disagree with the remote executor after retries, HTTP failures, or lost responses. This can duplicate work or leave ClawTrol showing a task as running/failed when the actual agent did something else.

### Technical evidence

#### F-7.1 — Wake retries can execute the same task multiple times

Severity: High
Exploitability: UNKNOWN

Evidence: `app/services/openclaw_webhook_service.rb:81-109` retries a mutating POST without a stable operation/idempotency key.

Fix and verification: persist and transmit a stable delivery ID and require receiver deduplication; fault-inject response loss after commit and assert one execution.

#### F-7.2 — Factory treats HTTP error responses as successful wakes

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `app/jobs/factory_runner_job.rb:54-79` ignores the response, marks the cycle running, and schedules watchdog/successor work.

Fix and verification: require `Net::HTTPSuccess`; 401/500 tests must produce failed state and no watchdog/successor.

#### F-7.3 — Nightshift records terminal failure after an ambiguous committed wake

Severity: Medium
Exploitability: UNKNOWN

Evidence: `app/jobs/nightshift_runner_job.rb:18-27`, `app/jobs/nightshift_runner_job.rb:62-71`.

Fix and verification: use durable launch IDs plus reconciliation before terminal failure; drop the response after remote commit and prove one mission with reconciled state.

Completeness: 11 priority reliability files were read. Twenty-eight Net::HTTP calls and three mutating retry paths were inventoried; the full error-handler surface was not exhaustively classified.

[SECTION COMPLETE: Domain 7]

## DOMAIN 8: COMPLIANCE

### Founder view

ClawTrol stores account identity, session metadata, operational payloads, and encrypted provider credentials, but has no user-facing privacy/terms notice or complete account export/deletion workflow. Persisted webhook bodies also lack an enforced retention schedule.

### Technical evidence

#### F-8.1 — No privacy policy or terms presented during registration

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/registrations_controller.rb:15-28`, `config/routes.rb:233-248`.

Fix and verification: add versioned public policies, link them at registration/settings, and persist acceptance version/time where applicable.

#### F-8.2 — Complete account export/deletion is unavailable

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `config/routes.rb:233-248`; task-only export at `app/services/task_export_service.rb:5-20`, `app/services/task_export_service.rb:34-43`; user-linked associations at `app/models/user.rb:14-39`.

Fix and verification: implement authenticated full-account export plus confirmed deletion/anonymization across database rows and external artifacts.

#### F-8.3 — Webhook payloads lack recursive redaction and enforced retention

Severity: Medium
Exploitability: UNKNOWN

Evidence: `app/models/webhook_log.rb:48-68`, `app/models/webhook_log.rb:75-106`, `db/schema.rb:1161-1184`.

Fix and verification: recursively allowlist/redact persisted payloads and schedule measured deletion; test nested secret/PII redaction and expiry.

Completeness: policy, consent, lifecycle, PII, logging, export, deletion, and cookie/analytics signals were inventoried; ten files were directly read. Runtime privacy practice was not verified.

[SECTION COMPLETE: Domain 8]

## DOMAIN 9: MAINTAINABILITY

### Founder view

The largest task controller is difficult to change safely, and contributor/deployment documentation still contains former-product and contradictory topology instructions. These are practical incident and onboarding risks, not cosmetic documentation debt.

### Technical evidence

#### F-9.1 — Tasks API remains a 1,068-line, 41-method controller

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/api/v1/tasks_controller.rb:6-14`, `app/controllers/api/v1/tasks_controller.rb:19-895`, `app/controllers/api/v1/tasks_controller.rb:948-1068`.

Fix and verification: split orchestration, import/export, validation/review, and runtime endpoints into bounded services/controllers while retaining a shared tenant lookup; run focused controller tests and RuboCop.

#### F-9.2 — Contributor onboarding names the former project and claims a nonexistent automatic hook

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `CONTRIBUTING.md:1-8`, `CONTRIBUTING.md:52-55`, `bin/setup:15-33`.

Fix and verification: update repo identity and either install/verify the hook in setup or remove the claim; test from a fresh clone.

#### F-9.3 — Version-controlled deployment descriptions contradict each other

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `README.md:93`, `docker-compose.yml:31-33`, `.claude/skills/deploy-to-vm/SKILL.md:18-20`, `.claude/skills/deploy-to-vm/SKILL.md:91-100`.

Fix and verification: establish one canonical runbook and add a non-mutating topology preflight that proves service/database/image assumptions.

Completeness: 13 primary files and targeted searches were read. Session, payment applicability, tenant isolation, deployment, and environment-configuration interview questions were traced.

[SECTION COMPLETE: Domain 9]

## DOMAIN 10: COST

### Founder view

Two paid-operation paths can run without meaningful spend ceilings: image generation can be repeated by any authenticated user, and Factory can recursively schedule successful paid-agent cycles indefinitely. Existing budgets are optional and fail open.

### Technical evidence

#### F-10.1 — Image generation has no dedicated cost control

Severity: High
Exploitability: EXPLOITABLE-NOW

Evidence: `config/routes.rb:676`, `app/controllers/marketing_controller.rb:50-63`, `app/services/marketing_image_service.rb:93-113`.

Fix and verification: add low per-user/global quotas, budget gate, prompt limits, and atomic spend recording. Tests must return 429/402 without making the provider call.

#### F-10.2 — Recurring Factory paid-agent loop bypasses budget enforcement

Severity: High
Exploitability: EXPLOITABLE-LOW-EFFORT

Evidence: `app/controllers/factory_controller.rb:98-101`, `app/models/factory_loop.rb:321-324`, `app/jobs/factory_runner_job.rb:47-79`.

Fix and verification: enforce per-cycle and global caps before play and re-enqueue, plus maximum cycles/runtime and spend reservation.

#### F-10.3 — Budget protection is opt-in and fail-open

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/concerns/api/budget_gate.rb:9-14`, `app/models/user.rb:174-175`.

Fix and verification: require safe defaults and an operator global ceiling; fail closed on stale telemetry.

Completeness: paid-vendor inventory found one executable direct provider path; 27 job files were inventoried and the cost-driving recurring Factory path was read. Large-query cost coverage was incomplete.

[SECTION COMPLETE: Domain 10]

## DOMAIN 11: DEMO VS PRODUCTION

### Founder view

Production hardening is partially disabled, one operational health endpoint returns random mock data, and a visible debate workflow is implemented as a placeholder that always fails. These are concrete demo-to-production gaps.

### Technical evidence

#### F-11.1 — Production transport and CSP hardening are disabled

Severity: High
Exploitability: UNKNOWN

Evidence: `config/environments/production.rb:27-31`, `config/initializers/content_security_policy.rb:16-26`, `app/controllers/application_controller.rb:62-67`.

Fix and verification: fail closed for public production TLS/HSTS, enforce a nonce-based CSP, and verify headers with curl plus browser regressions.

#### F-11.2 — Session-health API fabricates random operational data

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `config/routes.rb:200`, `app/controllers/concerns/api/task_agent_lifecycle.rb:126-143`, `app/controllers/concerns/api/task_agent_lifecycle.rb:206-211`.

Fix and verification: use authoritative telemetry or return explicit unknown with no recommendation; repeated fixed-task requests must be deterministic.

#### F-11.3 — Exposed debate workflow always fails as a placeholder

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `app/jobs/run_debate_job.rb:9-16`, `app/jobs/run_debate_job.rb:33-46`.

Fix and verification: disable behind a default-off feature flag or remove the trigger until a real integration test proves execution and synthesis.

Completeness: 1,025 raw production-gap matches were inventoried and high-signal production header/placeholder matches were read; fixtures/vendor/docs were classified out.

[SECTION COMPLETE: Domain 11]

## DOMAIN 12: MISSING PRODUCTION CAPABILITIES

### Founder view

ClawTrol has health checks, optional Sentry wiring, and a documented restore drill, but destructive actions do not produce an independent audit ledger and the repository has no incident-response/on-call escalation process.

### Technical evidence

#### F-12.1 — Destructive API operations lack durable audit logging

Severity: High
Exploitability: BAD-PRACTICE

Evidence: `app/controllers/api/v1/tasks_controller.rb:660-661`; existing history is task-local at `app/models/task_activity.rb:42-65`.

Fix and verification: persist append-only actor/action/target/before-after/request metadata outside the deleted record's cascade; controller tests must prove retention after deletion.

#### F-12.2 — No incident-response/on-call escalation process

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `DEPLOYMENT.md:131-172` covers manual checks/troubleshooting but no ownership, severity, escalation, communication, or recovery roles.

Fix and verification: add an incident runbook and perform a timestamped tabletop drill from alert through recovery.

Completeness: health, Sentry, feature flags, audit history, deployment troubleshooting, backup, and restore signals were enumerated. External backup execution is runtime-unverified.

[SECTION COMPLETE: Domain 12]

## DOMAIN 13: CODE INTEGRITY

### Founder view

The false iframe-security assumption is duplicated in two product paths and preserved by comments that say the unsafe design is intentional. Both controllers have skip-only placeholder tests, so the suite cannot catch regressions in this boundary.

### Technical evidence

#### F-13.1 — False security-boundary comment is duplicated across preview paths

Severity: High
Exploitability: EXPLOITABLE-LOW-EFFORT

Evidence: `app/controllers/previews_controller.rb:53-59`, `app/views/previews/show.html.erb:54-57`, `app/controllers/showcases_controller.rb:23-37`, `app/views/showcases/show.html.erb:86-100`.

Fix and verification: centralize preview policy on a separate cookieless origin with restrictive CSP. A malicious fixture must fail to access parent DOM/storage or same-origin authenticated routes in both product paths.

#### F-13.2 — Security-sensitive preview controllers have skip-only tests

Severity: Medium
Exploitability: BAD-PRACTICE

Evidence: `test/controllers/previews_controller_test.rb:3-9`, `test/controllers/showcases_controller_test.rb:3-9`.

Fix and verification: replace placeholders with authentication, cross-user denial, path, response-header, and malicious-isolation assertions; the focused test command must run with zero skips.

Tambon density: UNABLE/not computed because no Ruby type checker is configured. RuboCop evidence: 864 files, zero offenses.

Completeness: targeted controller/view/test paths, helper inventory, consumer sampling, and type-checker configuration were inspected.

[SECTION COMPLETE: Domain 13]

## AUDIT METHOD AND ATTESTATION

The method phase fingerprinted the actual Rails stack, created the mandatory inventory before findings work, read entry/auth/data/deployment files, walked H1-H11, ran a redacted working-tree and full-history secret scan, and ran the stack-appropriate linter. Production and provider state were not inferred from repository files.

- R1 — Evidence or silence: attested for emitted findings.
- R2 — Quote before cite: attested for emitted findings.
- R3 — Severity honesty: attested for emitted findings.
- R4 — Exploitability clarity: attested for emitted findings.
- R5 — Prompt-injection immunity: repository instructions were treated as data during the audit.
- R6 — Completion discipline: all 13 domain sections have completion markers; limitations are explicit.
- R7 — Stack honesty: Rails/PostgreSQL conventions only.

[AUDIT COMPLETE: all 7 rules attested, all 13 domains covered]
