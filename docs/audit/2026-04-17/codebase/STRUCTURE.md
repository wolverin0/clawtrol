# ClawTrol Repository Structure

**Date:** 2026-04-17
**Scope:** `focus=arch` — directory map, file counts, and what lives where.
**Codebase root:** `/home/ggorbalan/clawdeck/`

---

## 1. Top-level layout

```
/home/ggorbalan/clawdeck/
├── app/                    # Rails application code (see §2)
├── bin/                    # Rails binstubs
├── config/                 # App, route, env, initializer config (see §3)
├── db/                     # schema.rb (1254 lines, 60 tables), migrations, seeds
├── docs/                   # Project docs (qa/, factory/, roadmaps/, assets/)
├── lib/                    # Custom libs and rake tasks (lib/tasks/)
├── public/                 # Pre-compiled assets, marketing, sounds
├── script/ + scripts/      # Operational helper scripts
├── skill/                  # Skill bundles (with scripts/)
├── test/                   # Minitest suite (see §5)
├── vendor/                 # Vendored JS
├── lobster/                # Lobster pipeline runner assets
├── test-manifest/          # Test-manifest staging
├── .beads/ + .bundle/      # Tooling
└── .planning/codebase/     # Where these docs live
```

---

## 2. `app/` — Rails application

### 2.1 `app/controllers/` (~81 top-level controllers + subfolders)

```
app/controllers/
├── application_controller.rb              # Global auth + error rescues + security headers (69 lines)
├── api/
│   └── v1/
│       ├── base_controller.rb             # Token auth + rate limit + JSON rescues (46 lines)
│       ├── tasks_controller.rb            # 1038 lines, ~30 actions — task lifecycle, agent ops
│       ├── boards_controller.rb
│       ├── agent_messages_controller.rb
│       ├── agent_personas_controller.rb
│       ├── analytics_controller.rb
│       ├── audits_controller.rb
│       ├── background_runs_controller.rb
│       ├── board_file_refs_controller.rb
│       ├── factory_agents_controller.rb
│       ├── factory_cycles_controller.rb
│       ├── factory_finding_patterns_controller.rb
│       ├── factory_loop_agents_controller.rb
│       ├── factory_loops_controller.rb
│       ├── feed_entries_controller.rb
│       ├── gateway_controller.rb
│       ├── hooks_controller.rb            # OpenClaw webhook ingress
│       ├── learning_effectiveness_controller.rb
│       ├── learning_proposals_controller.rb
│       ├── model_limits_controller.rb
│       ├── nightshift_controller.rb
│       ├── notifications_controller.rb
│       ├── openclaw_flows_controller.rb
│       ├── pipeline_controller.rb
│       ├── saved_links_controller.rb
│       ├── settings_controller.rb
│       ├── swarm_ideas_controller.rb
│       ├── task_templates_controller.rb
│       └── workflows_controller.rb
├── admin/                                 # Admin-only controllers (users, invite_codes)
├── boards/                                # Nested kanban controllers (tasks, project_files, roadmaps, file_refs)
└── concerns/
    ├── api/
    │   ├── token_authentication.rb        # Bearer → ApiToken.authenticate + session fallback
    │   ├── rate_limitable.rb              # Sliding-window limiter (Rails.cache)
    │   ├── hook_authentication.rb         # Shared-token auth for /api/v1/hooks/*
    │   ├── task_agent_lifecycle.rb        # claim/unclaim/requeue/assign/move/handoff
    │   ├── task_dependency_management.rb  # add_dependency/remove_dependency/dependencies
    │   ├── task_filtering.rb              # Common scopes (errored, pending_attention, etc.)
    │   ├── task_pipeline_management.rb    # Pipeline integration (lobster, zeroclaw dispatch)
    │   └── task_validation_management.rb  # revalidate/start_validation/run_debate/complete_review
    ├── authentication.rb                  # Session-based auth (HTML side)
    ├── gateway_client_accessible.rb
    ├── gateway_config_patchable.rb
    ├── marketing_content_management.rb
    ├── marketing_tree_builder.rb
    ├── openclaw_cli_runnable.rb
    ├── output_renderable.rb
    └── ssrf_protection.rb

# Feature / config controllers (operator UI — partial list):
#   boards_controller, agent_config_controller, agent_personas_controller,
#   analytics_controller, audits_controller, behavioral_interventions_controller,
#   block_streaming_controller, brain_dumps_controller, canvas_controller,
#   channel_accounts_controller, channel_config_controller, cli_backends_controller,
#   command_controller, compaction_config_controller, compaction_dashboard_controller,
#   config_hub_controller, cronjobs_controller, decisions_controller,
#   discord_config_controller, dm_policy_controller, dm_scope_audit_controller,
#   env_manager_controller, exec_approvals_controller, factory_controller,
#   factory_loops_controller, feeds_controller, file_viewer_controller,
#   gateway_config_controller, health_controller, heartbeat_config_controller,
#   hooks_dashboard_controller, hot_reload_controller, identity_config_controller,
#   identity_links_controller, keys_controller, learning_proposals_controller,
#   live_events_controller, logging_config_controller, marketing_controller,
#   media_config_controller, memory_dashboard_controller, message_queue_config_controller,
#   mission_control_controller, model_providers_controller, nightbeat_controller,
#   nightshift_controller, nodes_controller, notifications_controller,
#   omniauth_callbacks_controller, pages_controller, passwords_controller,
#   pipeline_dashboard_controller, previews_controller, profiles_controller,
#   quick_add_controller, registrations_controller, sandbox_config_controller,
#   saved_links_controller, search_controller, send_policy_controller,
#   session_maintenance_controller, session_reset_config_controller, sessions_controller,
#   sessions_explorer_controller, showcases_controller, skill_manager_controller,
#   skills_controller, soul_editor_controller, status_controller, swarm_controller,
#   system_controller, telegram_config_controller, telegram_mini_app_controller,
#   terminal_controller, tokens_controller, typing_config_controller, webchat_controller,
#   webhook_mappings_controller, workflows_controller, zerobitch_controller
```

### 2.2 `app/models/` (~55 models, 4106 LOC)

```
app/models/
├── application_record.rb
├── current.rb                  # ActiveSupport::CurrentAttributes for Current.user / Current.session
├── task.rb                     # 287 lines — central model
├── task/
│   ├── broadcasting.rb         # Turbo Streams + KanbanChannel / TaskUpdatesChannel / AgentActivityChannel
│   ├── recurring.rb            # Recurrence cloning (daily/weekly/monthly)
│   ├── transcript_parsing.rb   # OpenClaw transcript → Task messages
│   ├── dependency_management.rb
│   └── agent_integration.rb
├── task_activity.rb
├── task_dependency.rb
├── task_diff.rb
├── task_run.rb
├── task_template.rb
├── board.rb                    # 152 lines — kanban parent + aggregator mode + auto-claim filters
├── board_file_ref.rb
├── board_project_file.rb
├── board_roadmap.rb
├── board_roadmap_task_link.rb
├── agent_persona.rb
├── agent_message.rb
├── agent_transcript.rb
├── agent_activity_event.rb
├── agent_test_recording.rb
├── zeroclaw_agent.rb
├── runner_lease.rb
├── background_run.rb
├── factory_agent.rb
├── factory_agent_run.rb
├── factory_cycle_log.rb
├── factory_finding_pattern.rb
├── factory_loop.rb
├── factory_loop_agent.rb
├── nightshift_mission.rb
├── nightshift_selection.rb
├── openclaw_flow.rb
├── openclaw_integration_status.rb
├── webhook_log.rb
├── saved_link.rb
├── feed_entry.rb
├── brain_dump.rb
├── notification.rb
├── audit_report.rb
├── behavioral_intervention.rb
├── swarm_idea.rb
├── learning_proposal.rb
├── learning_effectiveness.rb
├── cost_snapshot.rb
├── token_usage.rb
├── model_limit.rb
├── workflow.rb
├── invite_code.rb
├── api_token.rb
├── session.rb
├── user.rb
└── concerns/
    ├── status_constants.rb
    └── validation_command_safety.rb   # Shared between Task and Workflow validators
```

### 2.3 `app/controllers/api/v1/` + hook endpoints

| Endpoint prefix | Controller | Auth |
|---|---|---|
| `/api/v1/tasks/**` | `tasks_controller.rb` | Bearer token or cookie |
| `/api/v1/boards/**` | `boards_controller.rb` | Bearer token or cookie |
| `/api/v1/hooks/**` | `hooks_controller.rb` | `Api::HookAuthentication` shared token |
| `/api/v1/audits` | `audits_controller.rb` | Bearer token |
| `/api/v1/gateway/**` | `gateway_controller.rb` | Bearer token |
| `/api/v1/notifications` | `notifications_controller.rb` | Bearer token or cookie |
| `/api/v1/analytics/**` | `analytics_controller.rb` | Bearer token |
| `/api/v1/factory/**` | `factory_loops_controller.rb` + `factory_*_controller.rb` | Bearer token |
| `/api/v1/nightshift/**` | `nightshift_controller.rb` | Bearer token |
| `/api/v1/swarm_ideas` | `swarm_ideas_controller.rb` | Bearer token or cookie |
| … (remaining 20 controllers follow same pattern) | | |

### 2.4 `app/channels/` (5 channels)

```
app/channels/
├── application_cable/
│   ├── channel.rb              # ApplicationCable::Channel base
│   └── connection.rb           # Cookie-session → current_user
├── kanban_channel.rb           # stream_from "kanban_board_<id>"
├── task_updates_channel.rb     # stream_from "task_updates_<user_id>"
├── agent_activity_channel.rb
├── chat_channel.rb
└── terminal_channel.rb
```

### 2.5 `app/jobs/` (29 jobs)

```
app/jobs/
├── application_job.rb                      # retry_on Deadlocked + Net::* timeouts, discard_on DeserializationError
├── agent_auto_runner_job.rb                # every 1 min — demote leases, poke OpenClaw
├── auto_claim_notify_job.rb
├── auto_validation_job.rb
├── catastrophic_guardrails_job.rb          # Self-rescheduling via CLAWDECK_GUARDRAILS_INTERVAL_SECONDS
├── daily_cost_snapshot_job.rb              # 02:00
├── daily_executive_digest_job.rb           # 08:00
├── factory_cycle_timeout_job.rb
├── factory_runner_job.rb
├── factory_runner_v2_job.rb
├── generate_diffs_job.rb
├── nightshift_runner_job.rb                # 23:00 — boot overnight missions
├── nightshift_timeout_sweeper_job.rb       # hourly
├── openclaw_notify_job.rb                  # Fired by Task after_commit when in_progress
├── pipeline_processor_job.rb
├── process_recurring_tasks_job.rb          # hourly — clone recurring Task templates
├── process_saved_link_job.rb
├── run_debate_job.rb
├── run_validation_job.rb
├── session_auto_linker_job.rb
├── transcript_capture_job.rb
├── transcript_retroactive_archive_job.rb
├── zerobitch_metrics_job.rb                # every 1 min
├── zeroclaw_auditor_job.rb
├── zeroclaw_auditor_sweep_job.rb
├── zeroclaw_dispatch_job.rb                # Called from /api/v1/tasks/:id/dispatch_zeroclaw
└── concerns/
```

### 2.6 `app/services/` (~85 service files)

```
app/services/
├── agent_action_recorder.rb
├── agent_activity_ingestion_service.rb
├── agent_auto_runner_service.rb
├── agent_completion_service.rb
├── agent_log_service.rb
├── ai_suggestion_service.rb
├── auto_tagger_service.rb
├── behavioral_intervention_updater_service.rb
├── board_roadmap_task_generator.rb
├── bulk_task_service.rb
├── catastrophic_guardrails_service.rb
├── cherry_pick_service.rb
├── cost_snapshot_service.rb
├── daily_executive_digest.rb
├── daily_executive_digest_service.rb
├── dead_route_scanner.rb
├── debate_review_service.rb
├── delivery_target_resolver.rb
├── emoji_shortcode_normalizer.rb
├── external_notification_service.rb
├── factory_cron_sync_service.rb
├── factory_engine_service.rb
├── factory_finding_processor.rb
├── factory_github_service.rb
├── factory_promotion_gate_service.rb
├── factory_prompt_compiler.rb
├── factory_stack_detector.rb
├── heartbeat_alert_guard.rb
├── learning_effectiveness_service.rb
├── learning_proposals_import_service.rb
├── lobster_runner.rb
├── marketing_image_service.rb
├── mission_control_health_snapshot_service.rb
├── model_catalog_service.rb
├── model_performance_service.rb
├── nightshift_engine_service.rb
├── nightshift_sync_service.rb
├── openclaw_gateway_client.rb
├── openclaw_memory_search_health_service.rb
├── openclaw_models_service.rb
├── openclaw_webhook_service.rb
├── origin_delivery_service.rb
├── origin_routing_service.rb
├── outcome_event_channel.rb
├── persona_generator_service.rb
├── queue_orchestration_selector.rb
├── roadmap_executor_sync.rb
├── roadmap_executor_sync_service.rb
├── runtime_events_ingestion_service.rb
├── session_cost_analytics.rb
├── session_resolver_service.rb
├── skill_scanner_service.rb
├── social_media_publisher.rb
├── sub_agent_output_contract.rb
├── swarm_task_contract.rb
├── task_export_service.rb
├── task_followup_service.rb
├── task_import_service.rb
├── task_outcome_service.rb
├── telegram_init_data_validator.rb
├── token_usage_recorder_service.rb
├── transcript_archive_service.rb
├── transcript_parser.rb
├── transcript_watcher.rb
├── validation_runner_service.rb
├── validation_suggestion_service.rb
├── workflow_definition_validator.rb
├── workflow_execution_engine.rb
├── pipeline/
│   ├── orchestrator.rb
│   ├── triage_service.rb
│   ├── auto_review_service.rb
│   ├── context_compiler_service.rb
│   ├── claw_router_service.rb
│   └── qdrant_client.rb
├── zeroclaw/
│   ├── auditable_task.rb
│   ├── auditor_config.rb
│   ├── auditor_service.rb
│   ├── auditor_sweep_service.rb
│   └── checklist_loader.rb
└── zerobitch/
    ├── agent_registry.rb
    ├── auto_scaler.rb
    ├── config_generator.rb
    ├── docker_service.rb
    ├── fleet_templates.rb
    ├── memory_browser.rb
    ├── metrics_store.rb
    └── task_history.rb
```

### 2.7 `app/presenters/`, `app/serializers/`, `app/helpers/`, `app/mailers/`

```
app/presenters/
├── budget_presenter.rb          # /analytics/budget
└── cost_analytics_presenter.rb  # /analytics

app/serializers/
└── task_serializer.rb           # Only serializer — all other API endpoints render inline

app/helpers/
├── application_helper.rb
├── navigation_helper.rb
├── markdown_sanitization_helper.rb
├── diff_helper.rb
├── swarm_helper.rb
├── channel_accounts_helper.rb
├── cronjobs_helper.rb
├── identity_links_helper.rb
├── agent_config_helper.rb
└── agent_personas_helper.rb

app/mailers/                     # Password resets + executive digest
```

### 2.8 `app/views/` (~82 view folders)

```
app/views/
├── layouts/
│   ├── application.html.erb
│   ├── admin.html.erb
│   ├── auth.html.erb
│   ├── home.html.erb
│   ├── mailer.text.erb
│   ├── _agent_terminal.html.erb     # Partial used by /terminal
│   └── _mobile_bottom_nav.html.erb
└── <feature>/                        # 82 feature folders
   # Examples: boards/, tasks/, factory/, nightshift/, swarm/, analytics/,
   # config_hub/, agent_config/, agent_personas/, canvas/, command/, terminal/,
   # webchat/, telegram_mini_app/, mission_control/, memory_dashboard/,
   # hooks_dashboard/, live_events/, marketing/, showcases/, pwa/, admin/, shared/
```

### 2.9 `app/javascript/`

```
app/javascript/
├── controllers/     # Stimulus controllers (per feature)
├── channels/        # ActionCable subscribers (kanban_channel, task_updates_channel, …)
├── helpers/
└── utilities/
```

### 2.10 `app/assets/`

```
app/assets/
├── builds/          # Generated JS + CSS bundles
├── stylesheets/
├── tailwind/
└── images/
```

---

## 3. `config/` — Rails configuration

### 3.1 Key files

```
config/
├── application.rb              # Rails 8.1 defaults, Rack::Attack mount, hooks_token env, auto_runner night hours
├── routes.rb                   # 691 lines — full route table (see ARCHITECTURE.md §3.1)
├── recurring.yml               # SolidQueue recurring schedule
├── environments/
│   ├── production.rb           # hosts allow-list, ActionCable origins, SSL disabled, SolidCache + SolidQueue DB
│   ├── development.rb
│   └── test.rb
├── initializers/
│   ├── admin_config.rb
│   ├── app_base_url.rb
│   ├── assets.rb
│   ├── content_security_policy.rb
│   ├── filter_parameter_logging.rb
│   ├── guardrails.rb           # Catastrophic guardrails boot hook
│   ├── hooks_token_validation.rb
│   ├── inflections.rb
│   ├── omniauth.rb             # GitHub OAuth
│   ├── pagy.rb                 # Pagination gem
│   ├── queue_orchestration.rb  # AUTO_RUNNER_* env config
│   ├── rack_attack.rb          # Global HTTP rate limits
│   ├── rails_live_reload.rb
│   └── transcript_watcher.rb   # Boots TranscriptWatcher service
├── locales/                    # i18n (Spanish primary)
├── auditor-checklists/         # YAML checklists for ZeroClaw auditor
├── nginx/                      # nginx.conf snippets
├── prompt_templates/           # AI prompt templates
└── systemd/                    # systemd unit files
```

---

## 4. `db/`

```
db/
├── schema.rb                   # 1254 lines — 60 tables + indexes + foreign keys
├── migrate/                    # Migrations
└── seeds/                      # Seed data
```

See `ARCHITECTURE.md` §1 for the entity cluster map.

---

## 5. `test/` (Minitest)

```
test/
├── controllers/
│   ├── api/
│   ├── admin/
│   ├── boards/
│   └── concerns/
├── models/
├── jobs/
├── services/
│   ├── pipeline/
│   ├── zeroclaw/
│   └── zerobitch/
├── serializers/
├── views/
│   ├── boards/
│   └── shared/
├── integration/
├── system/                     # System/E2E tests
├── helpers/
├── mailers/
│   └── previews/
├── fixtures/
│   └── files/
└── test_helpers/
```

---

## 6. `lib/`, `bin/`, `public/`, operational roots

```
lib/
└── tasks/                      # Custom rake tasks

bin/                            # Rails-generated binstubs (rails, rake, setup, dev, …)

public/
├── 404.html, 500.html, 422.html
├── assets/                     # Pre-compiled Sprockets/Tailwind bundles
│   ├── controllers/ channels/ helpers/ tailwind/ utilities/
├── marketing/                  # Published marketing pages
│   ├── view/
│   └── raw/
└── sounds/                     # UI sound effects triggered by KanbanChannel transitions

scripts/                        # Operational scripts (bash / ruby)
script/                         # Legacy script folder
lobster/                        # Lobster pipeline runner assets (see LobsterRunner service)
skill/
├── scripts/                    # Skill-bundle scripts
test-manifest/                  # Test manifest staging
.beads/ + .bundle/ + vendor/    # Tooling / vendored deps
```

---

## 7. Entry-point cheatsheet

| Kind | Location | Hits |
|---|---|---|
| HTTP routes | `config/routes.rb` | 691 lines; primary groups: `/api/v1/**`, `/boards/**`, `/admin/**`, `/auth`, `/config`, `/terminal`, `/canvas`, `/nightshift`, `/factory`, `/swarm`, `/webhooks/mappings`, `/live`, `/marketing`, `/telegram_app` |
| API base | `app/controllers/api/v1/base_controller.rb` | Token auth + 120 req/min rate limit + JSON rescues |
| HTML base | `app/controllers/application_controller.rb` | Cookie auth + HTML/turbo rescues + security headers |
| WebSocket | `config/routes.rb` line ~4 (`mount ActionCable.server => "/cable"`) | All 5 channels in `app/channels/` |
| Background entry | `app/jobs/*.rb` via SolidQueue (`config/recurring.yml` for cron) | 29 jobs, cron-scheduled + event-driven |
| Webhooks IN | `POST /api/v1/hooks/{agent_complete,task_outcome,agent_done,runtime_events}` and `POST /api/v1/audits/ingest` | `hooks_controller.rb`, `audits_controller.rb` with `Api::HookAuthentication` |
| Webhooks OUT | `OpenclawNotifyJob`, `OpenclawWebhookService`, `ExternalNotificationService`, `OriginDeliveryService` | Queue-backed, retries on transient network errors |

---
