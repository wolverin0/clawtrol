# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_12_051459) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_personas", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "emoji", default: "🤖"
    t.string "fallback_model"
    t.string "model", default: "sonnet"
    t.string "name", null: false
    t.string "project"
    t.string "role"
    t.text "system_prompt"
    t.string "tier"
    t.text "tools", default: [], array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id", "name"], name: "index_agent_personas_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_agent_personas_on_user_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name"
    t.string "token_digest", null: false
    t.string "token_prefix", limit: 8
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "boards", force: :cascade do |t|
    t.boolean "auto_claim_enabled", default: false, null: false
    t.string "auto_claim_prefix"
    t.string "auto_claim_tags", default: [], array: true
    t.string "color", default: "gray"
    t.datetime "created_at", null: false
    t.string "icon", default: "📋"
    t.boolean "is_aggregator", default: false, null: false
    t.datetime "last_auto_claim_at"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["auto_claim_enabled"], name: "index_boards_on_auto_claim_enabled", where: "(auto_claim_enabled = true)"
    t.index ["is_aggregator"], name: "index_boards_on_is_aggregator", where: "(is_aggregator = true)"
    t.index ["user_id", "position"], name: "index_boards_on_user_id_and_position"
    t.index ["user_id"], name: "index_boards_on_user_id"
  end

  create_table "model_limits", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "last_error_at"
    t.boolean "limited", default: false, null: false
    t.string "name", null: false
    t.datetime "resets_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["resets_at"], name: "index_model_limits_on_resets_at", where: "(limited = true)"
    t.index ["user_id", "name"], name: "index_model_limits_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_model_limits_on_user_id"
  end

  create_table "nightshift_selections", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "launched_at"
    t.integer "mission_id", null: false
    t.text "result"
    t.date "scheduled_date", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["mission_id", "scheduled_date"], name: "index_nightshift_selections_on_mission_id_and_scheduled_date", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "message", null: false
    t.datetime "read_at"
    t.bigint "task_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type"], name: "index_notifications_on_event_type"
    t.index ["task_id"], name: "index_notifications_on_task_id"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_unread"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "openclaw_integration_statuses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "memory_search_last_checked_at"
    t.text "memory_search_last_error"
    t.datetime "memory_search_last_error_at"
    t.integer "memory_search_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_openclaw_integration_statuses_on_user_id", unique: true
  end

  create_table "runner_leases", force: :cascade do |t|
    t.string "agent_name"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_heartbeat_at", null: false
    t.string "lease_token", null: false
    t.datetime "released_at"
    t.string "source", default: "auto_runner", null: false
    t.datetime "started_at", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_runner_leases_on_expires_at"
    t.index ["lease_token"], name: "index_runner_leases_on_lease_token", unique: true
    t.index ["task_id"], name: "index_runner_leases_on_task_id"
    t.index ["task_id"], name: "index_runner_leases_on_task_id_active", unique: true, where: "(released_at IS NULL)"
  end

  create_table "saved_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "error_message"
    t.datetime "processed_at"
    t.text "raw_content"
    t.string "source_type"
    t.integer "status"
    t.text "summary"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_saved_links_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "task_activities", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_emoji"
    t.string "actor_name"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "field_name"
    t.string "new_value"
    t.text "note"
    t.string "old_value"
    t.string "source", default: "web"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["task_id", "created_at"], name: "index_task_activities_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_activities_on_task_id"
    t.index ["user_id"], name: "index_task_activities_on_user_id"
  end

  create_table "task_dependencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "depends_on_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["depends_on_id"], name: "index_task_dependencies_on_depends_on_id"
    t.index ["task_id", "depends_on_id"], name: "index_task_dependencies_on_task_id_and_depends_on_id", unique: true
    t.index ["task_id"], name: "index_task_dependencies_on_task_id"
  end

  create_table "task_diffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "diff_content"
    t.string "diff_type", default: "modified"
    t.string "file_path", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "file_path"], name: "index_task_diffs_on_task_id_and_file_path", unique: true
    t.index ["task_id"], name: "index_task_diffs_on_task_id"
  end

  create_table "task_runs", force: :cascade do |t|
    t.jsonb "achieved", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.jsonb "evidence", default: [], null: false
    t.string "model_used"
    t.boolean "needs_follow_up", default: false, null: false
    t.text "next_prompt"
    t.string "openclaw_session_id"
    t.string "openclaw_session_key"
    t.jsonb "raw_payload", default: {}, null: false
    t.string "recommended_action", default: "in_review", null: false
    t.jsonb "remaining", default: [], null: false
    t.uuid "run_id", null: false
    t.integer "run_number", null: false
    t.text "summary"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id"], name: "index_task_runs_on_run_id", unique: true
    t.index ["task_id", "run_number"], name: "index_task_runs_on_task_id_and_run_number", unique: true
    t.index ["task_id"], name: "index_task_runs_on_task_id"
  end

  create_table "task_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description_template"
    t.boolean "global", default: false
    t.string "icon"
    t.string "model"
    t.string "name", null: false
    t.integer "priority", default: 0
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "validation_command"
    t.index ["slug"], name: "index_task_templates_on_slug"
    t.index ["slug"], name: "index_task_templates_on_slug_global", unique: true, where: "(global = true)"
    t.index ["user_id", "slug"], name: "index_task_templates_on_user_id_and_slug", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["user_id"], name: "index_task_templates_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "agent_claimed_at"
    t.bigint "agent_persona_id"
    t.string "agent_session_id"
    t.string "agent_session_key"
    t.datetime "archived_at"
    t.datetime "assigned_at"
    t.boolean "assigned_to_agent", default: false, null: false
    t.boolean "auto_pull_blocked", default: false, null: false
    t.integer "auto_pull_failures", default: 0, null: false
    t.datetime "auto_pull_last_attempt_at"
    t.text "auto_pull_last_error"
    t.datetime "auto_pull_last_error_at"
    t.boolean "blocked", default: false, null: false
    t.bigint "board_id", null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.integer "context_usage_percent"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.datetime "error_at"
    t.text "error_message"
    t.bigint "followup_task_id"
    t.boolean "last_needs_follow_up"
    t.datetime "last_outcome_at"
    t.string "last_recommended_action"
    t.uuid "last_run_id"
    t.string "model"
    t.string "name"
    t.datetime "next_recurrence_at"
    t.boolean "nightly", default: false, null: false
    t.integer "nightly_delay_hours"
    t.jsonb "output_files", default: [], null: false
    t.bigint "parent_task_id"
    t.integer "position"
    t.integer "priority", default: 0, null: false
    t.string "recurrence_rule"
    t.time "recurrence_time"
    t.boolean "recurring", default: false, null: false
    t.integer "retry_count", default: 0
    t.jsonb "review_config", default: {}
    t.jsonb "review_result", default: {}
    t.string "review_status"
    t.string "review_type"
    t.integer "run_count", default: 0, null: false
    t.boolean "showcase_winner", default: false, null: false
    t.jsonb "state_data", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.text "suggested_followup"
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "validation_command"
    t.text "validation_output"
    t.string "validation_status"
    t.index ["agent_persona_id"], name: "index_tasks_on_agent_persona_id"
    t.index ["archived_at"], name: "index_tasks_on_archived_at", where: "(archived_at IS NOT NULL)"
    t.index ["assigned_to_agent"], name: "index_tasks_on_assigned_to_agent"
    t.index ["auto_pull_blocked"], name: "index_tasks_on_auto_pull_blocked"
    t.index ["blocked"], name: "index_tasks_on_blocked"
    t.index ["board_id", "status", "position"], name: "index_tasks_on_board_status_position"
    t.index ["board_id"], name: "index_tasks_on_board_id"
    t.index ["description"], name: "index_tasks_on_description_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["error_at"], name: "index_tasks_on_error_at", where: "(error_at IS NOT NULL)"
    t.index ["followup_task_id"], name: "index_tasks_on_followup_task_id"
    t.index ["name"], name: "index_tasks_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["next_recurrence_at"], name: "index_tasks_on_next_recurrence_at"
    t.index ["nightly"], name: "index_tasks_on_nightly"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["position"], name: "index_tasks_on_position"
    t.index ["recurring"], name: "index_tasks_on_recurring"
    t.index ["review_status"], name: "index_tasks_on_review_status", where: "(review_status IS NOT NULL)"
    t.index ["review_type"], name: "index_tasks_on_review_type", where: "(review_type IS NOT NULL)"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["user_id", "assigned_to_agent", "status"], name: "index_tasks_on_user_agent_status"
    t.index ["user_id", "status"], name: "index_tasks_on_user_status"
    t.index ["user_id"], name: "index_tasks_on_user_id"
    t.index ["validation_status"], name: "index_tasks_on_validation_status", where: "(validation_status IS NOT NULL)"
  end

  create_table "token_usages", force: :cascade do |t|
    t.bigint "agent_persona_id"
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0
    t.string "model"
    t.integer "output_tokens", default: 0
    t.string "session_key"
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_persona_id"], name: "index_token_usages_on_agent_persona_id"
    t.index ["created_at"], name: "index_token_usages_on_created_at"
    t.index ["model"], name: "index_token_usages_on_model"
    t.index ["session_key"], name: "index_token_usages_on_session_key"
    t.index ["task_id"], name: "index_token_usages_on_task_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.boolean "agent_auto_mode", default: true, null: false
    t.string "agent_emoji"
    t.datetime "agent_last_active_at"
    t.string "agent_name"
    t.string "ai_api_key"
    t.string "ai_suggestion_model", default: "glm"
    t.string "auto_retry_backoff", default: "1min"
    t.boolean "auto_retry_enabled", default: false
    t.integer "auto_retry_max", default: 3
    t.string "avatar_url"
    t.integer "context_threshold_percent", default: 70, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "fallback_model_chain"
    t.string "openclaw_gateway_token"
    t.string "openclaw_gateway_url"
    t.string "openclaw_hooks_token"
    t.string "password_digest"
    t.string "provider"
    t.string "theme", default: "default", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  create_table "workflows", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.jsonb "definition", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_personas", "users"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "boards", "users"
  add_foreign_key "model_limits", "users"
  add_foreign_key "notifications", "tasks"
  add_foreign_key "notifications", "users"
  add_foreign_key "openclaw_integration_statuses", "users"
  add_foreign_key "runner_leases", "tasks"
  add_foreign_key "saved_links", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "task_activities", "tasks"
  add_foreign_key "task_activities", "users"
  add_foreign_key "task_dependencies", "tasks"
  add_foreign_key "task_dependencies", "tasks", column: "depends_on_id"
  add_foreign_key "task_diffs", "tasks"
  add_foreign_key "task_runs", "tasks"
  add_foreign_key "task_templates", "users"
  add_foreign_key "tasks", "agent_personas"
  add_foreign_key "tasks", "boards"
  add_foreign_key "tasks", "tasks", column: "followup_task_id", on_delete: :nullify
  add_foreign_key "tasks", "tasks", column: "parent_task_id", on_delete: :nullify
  add_foreign_key "tasks", "users"
  add_foreign_key "token_usages", "agent_personas"
  add_foreign_key "token_usages", "tasks"
end
