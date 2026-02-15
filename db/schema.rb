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

ActiveRecord::Schema[8.1].define(version: 2026_02_16_050004) do
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

  create_table "agent_messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "direction", default: "incoming", null: false
    t.string "message_type", default: "output", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "sender_model", limit: 100
    t.string "sender_name", limit: 100
    t.string "sender_session_id", limit: 200
    t.bigint "source_task_id"
    t.text "summary"
    t.bigint "task_id", null: false
    t.index ["direction"], name: "index_agent_messages_on_direction"
    t.index ["source_task_id"], name: "idx_agent_messages_source_task", where: "(source_task_id IS NOT NULL)"
    t.index ["source_task_id"], name: "index_agent_messages_on_source_task_id"
    t.index ["task_id", "created_at"], name: "idx_agent_messages_task_timeline"
    t.index ["task_id"], name: "index_agent_messages_on_task_id"
  end

  create_table "agent_personas", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "auto_generated", default: false
    t.bigint "board_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "emoji", default: "🤖"
    t.string "fallback_model"
    t.string "model", default: "sonnet"
    t.string "name", null: false
    t.string "project"
    t.string "role"
    t.text "system_prompt"
    t.integer "tasks_count", default: 0
    t.string "tier"
    t.text "tools", default: [], array: true
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["board_id"], name: "index_agent_personas_on_board_id"
    t.index ["user_id", "name"], name: "index_agent_personas_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_agent_personas_on_user_id"
  end

  create_table "agent_test_recordings", force: :cascade do |t|
    t.integer "action_count", default: 0, null: false
    t.jsonb "actions", default: [], null: false
    t.jsonb "assertions", default: [], null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "generated_test_code"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", limit: 255, null: false
    t.string "session_id", limit: 100
    t.string "status", limit: 20, default: "recorded", null: false
    t.bigint "task_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "verified_at"
    t.index ["session_id"], name: "index_agent_test_recordings_on_session_id"
    t.index ["status"], name: "index_agent_test_recordings_on_status"
    t.index ["task_id"], name: "index_agent_test_recordings_on_task_id"
    t.index ["user_id", "created_at"], name: "index_agent_test_recordings_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_agent_test_recordings_on_user_id"
  end

  create_table "agent_transcripts", force: :cascade do |t|
    t.float "cost_usd"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.integer "message_count"
    t.jsonb "metadata", default: {}
    t.string "model"
    t.text "output_text"
    t.integer "output_tokens"
    t.text "prompt_text"
    t.text "raw_jsonl"
    t.integer "runtime_seconds"
    t.string "session_id", null: false
    t.string "session_key"
    t.string "status", default: "captured"
    t.bigint "task_id"
    t.bigint "task_run_id"
    t.integer "tool_call_count"
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "idx_agent_transcripts_cleanup"
    t.index ["session_id"], name: "index_agent_transcripts_on_session_id", unique: true
    t.index ["task_id"], name: "index_agent_transcripts_on_task_id"
    t.index ["task_run_id"], name: "index_agent_transcripts_on_task_run_id"
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

  create_table "audit_reports", force: :cascade do |t|
    t.jsonb "anti_pattern_counts", default: {}
    t.datetime "created_at", null: false
    t.integer "messages_analyzed", default: 0
    t.decimal "overall_score", precision: 4, scale: 1, null: false
    t.string "report_path"
    t.string "report_type", null: false
    t.jsonb "scores", default: {}
    t.integer "session_files_analyzed", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "worst_moments", default: []
    t.index ["user_id", "report_type", "created_at"], name: "index_audit_reports_on_user_id_and_report_type_and_created_at"
    t.index ["user_id"], name: "index_audit_reports_on_user_id"
  end

  create_table "behavioral_interventions", force: :cascade do |t|
    t.bigint "audit_report_id"
    t.decimal "baseline_score", precision: 4, scale: 1
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.decimal "current_score", precision: 4, scale: 1
    t.text "notes"
    t.datetime "regressed_at"
    t.datetime "resolved_at"
    t.text "rule", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["audit_report_id"], name: "index_behavioral_interventions_on_audit_report_id"
    t.index ["user_id", "status"], name: "index_behavioral_interventions_on_user_id_and_status"
    t.index ["user_id"], name: "index_behavioral_interventions_on_user_id"
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
    t.boolean "pipeline_enabled", default: false
    t.integer "position", default: 0, null: false
    t.integer "tasks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["auto_claim_enabled"], name: "index_boards_on_auto_claim_enabled", where: "(auto_claim_enabled = true)"
    t.index ["is_aggregator"], name: "index_boards_on_is_aggregator", where: "(is_aggregator = true)"
    t.index ["user_id", "name"], name: "index_boards_on_user_id_and_name", unique: true
    t.index ["user_id", "position"], name: "index_boards_on_user_id_and_position"
    t.index ["user_id"], name: "index_boards_on_user_id"
  end

  create_table "cost_snapshots", force: :cascade do |t|
    t.integer "api_calls", default: 0, null: false
    t.boolean "budget_exceeded", default: false, null: false
    t.decimal "budget_limit", precision: 10, scale: 2
    t.jsonb "cost_by_model", default: {}, null: false
    t.jsonb "cost_by_source", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "period", default: "daily", null: false
    t.date "snapshot_date", null: false
    t.jsonb "tokens_by_model", default: {}, null: false
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.integer "total_input_tokens", default: 0, null: false
    t.integer "total_output_tokens", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["budget_exceeded"], name: "index_cost_snapshots_on_budget_exceeded"
    t.index ["snapshot_date"], name: "index_cost_snapshots_on_snapshot_date"
    t.index ["user_id", "period", "snapshot_date"], name: "idx_cost_snapshots_user_period_date", unique: true
    t.index ["user_id"], name: "index_cost_snapshots_on_user_id"
  end

  create_table "factory_cycle_logs", force: :cascade do |t|
    t.jsonb "actions_taken", default: []
    t.datetime "created_at", null: false
    t.integer "cycle_number", null: false
    t.integer "duration_ms"
    t.jsonb "errors", default: []
    t.bigint "factory_loop_id", null: false
    t.datetime "finished_at"
    t.integer "input_tokens"
    t.string "model_used"
    t.string "openclaw_session_key"
    t.integer "output_tokens"
    t.datetime "started_at", null: false
    t.jsonb "state_after"
    t.jsonb "state_before"
    t.string "status", default: "running", null: false
    t.text "summary"
    t.index ["factory_loop_id", "created_at"], name: "idx_cycle_logs_loop_created"
    t.index ["factory_loop_id", "created_at"], name: "idx_cycle_logs_loop_recent", order: { created_at: :desc }
    t.index ["factory_loop_id", "cycle_number"], name: "idx_cycle_logs_loop_cycle", unique: true
    t.index ["factory_loop_id"], name: "index_factory_cycle_logs_on_factory_loop_id"
    t.index ["status"], name: "index_factory_cycle_logs_on_status"
  end

  create_table "factory_loops", force: :cascade do |t|
    t.integer "avg_cycle_duration_ms"
    t.jsonb "config", default: {}, null: false
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "cycle_count", default: 0
    t.text "description"
    t.string "fallback_model"
    t.string "icon", default: "🏭"
    t.integer "interval_ms", null: false
    t.datetime "last_cycle_at"
    t.datetime "last_error_at"
    t.text "last_error_message"
    t.jsonb "metrics", default: {}, null: false
    t.string "model", null: false
    t.string "name", null: false
    t.string "openclaw_cron_id"
    t.string "openclaw_session_key"
    t.string "slug", null: false
    t.jsonb "state", default: {}, null: false
    t.string "status", default: "idle", null: false
    t.text "system_prompt"
    t.integer "total_cycles", default: 0
    t.integer "total_errors", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["openclaw_cron_id"], name: "index_factory_loops_on_openclaw_cron_id", unique: true, where: "(openclaw_cron_id IS NOT NULL)"
    t.index ["slug"], name: "index_factory_loops_on_slug", unique: true
    t.index ["status"], name: "index_factory_loops_on_status"
    t.index ["user_id"], name: "index_factory_loops_on_user_id"
  end

  create_table "feed_entries", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "feed_name", null: false
    t.string "feed_url"
    t.datetime "published_at"
    t.datetime "read_at"
    t.float "relevance_score"
    t.integer "status", default: 0, null: false
    t.text "summary"
    t.string "tags", default: [], array: true
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.bigint "user_id", null: false
    t.index ["url"], name: "index_feed_entries_on_url", unique: true
    t.index ["user_id", "feed_name"], name: "index_feed_entries_on_user_id_and_feed_name"
    t.index ["user_id", "published_at"], name: "index_feed_entries_on_user_id_and_published_at", order: { published_at: :desc }
    t.index ["user_id", "relevance_score"], name: "index_feed_entries_on_user_id_and_relevance_score", order: { relevance_score: :desc }
    t.index ["user_id", "status"], name: "index_feed_entries_on_user_id_and_status"
    t.index ["user_id"], name: "index_feed_entries_on_user_id"
  end

  create_table "invite_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "email"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["code"], name: "index_invite_codes_on_code", unique: true
    t.index ["created_by_id"], name: "index_invite_codes_on_created_by_id"
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

  create_table "nightshift_missions", force: :cascade do |t|
    t.string "category", default: "general"
    t.datetime "created_at", null: false
    t.string "created_by", default: "user"
    t.jsonb "days_of_week", default: []
    t.text "description"
    t.boolean "enabled", default: true
    t.integer "estimated_minutes", default: 30
    t.string "frequency", default: "manual"
    t.string "icon", default: "🔧"
    t.datetime "last_run_at"
    t.string "model", default: "gemini"
    t.string "name", null: false
    t.integer "position", default: 0
    t.integer "selection_count", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["category"], name: "index_nightshift_missions_on_category"
    t.index ["enabled"], name: "index_nightshift_missions_on_enabled"
    t.index ["frequency"], name: "index_nightshift_missions_on_frequency"
    t.index ["user_id"], name: "index_nightshift_missions_on_user_id"
  end

  create_table "nightshift_selections", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "launched_at"
    t.bigint "nightshift_mission_id", null: false
    t.text "result"
    t.date "scheduled_date", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["nightshift_mission_id", "scheduled_date"], name: "index_nightshift_selections_on_mission_and_scheduled_date", unique: true
    t.index ["nightshift_mission_id"], name: "index_nightshift_selections_on_nightshift_mission_id"
    t.index ["scheduled_date", "enabled"], name: "index_nightshift_selections_on_date_enabled"
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
    t.index ["user_id", "event_type", "created_at"], name: "index_notifications_on_dedup", order: { created_at: :desc }
    t.index ["user_id", "read_at", "created_at"], name: "idx_notifications_inbox"
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
    t.boolean "deep_summary", default: false, null: false
    t.string "error_message"
    t.string "note"
    t.datetime "processed_at"
    t.text "raw_content"
    t.string "source_type"
    t.integer "status"
    t.text "summary"
    t.string "summary_file_path"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_saved_links_on_status"
    t.index ["user_id", "created_at"], name: "index_saved_links_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id", "url"], name: "index_saved_links_on_user_id_and_url", unique: true
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

  create_table "swarm_ideas", force: :cascade do |t|
    t.integer "board_id"
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "difficulty"
    t.boolean "enabled", default: true
    t.integer "estimated_minutes", default: 15
    t.boolean "favorite", default: false, null: false
    t.string "icon", default: "🚀"
    t.datetime "last_launched_at"
    t.string "pipeline_type"
    t.string "project"
    t.string "source"
    t.string "suggested_model"
    t.integer "times_launched", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["board_id"], name: "index_swarm_ideas_on_board_id"
    t.index ["category"], name: "index_swarm_ideas_on_category"
    t.index ["user_id", "enabled"], name: "index_swarm_ideas_on_user_id_and_enabled"
    t.index ["user_id", "favorite"], name: "index_swarm_ideas_on_user_id_and_favorite"
    t.index ["user_id"], name: "index_swarm_ideas_on_user_id"
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
    t.index ["openclaw_session_id"], name: "index_task_runs_on_openclaw_session_id"
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
    t.string "pipeline_type"
    t.integer "priority", default: 0
    t.string "slug", null: false
    t.string "tags", default: [], array: true
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
    t.jsonb "agent_context"
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
    t.text "compiled_prompt"
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.integer "context_usage_percent"
    t.datetime "created_at", null: false
    t.boolean "deep_research", default: false, null: false
    t.text "description"
    t.date "due_date"
    t.datetime "error_at"
    t.text "error_message"
    t.text "execution_plan"
    t.bigint "followup_task_id"
    t.boolean "last_needs_follow_up"
    t.datetime "last_outcome_at"
    t.string "last_recommended_action"
    t.uuid "last_run_id"
    t.integer "lock_version", default: 0, null: false
    t.string "model"
    t.string "name"
    t.datetime "next_recurrence_at"
    t.boolean "nightly", default: false, null: false
    t.integer "nightly_delay_hours"
    t.string "origin_chat_id"
    t.integer "origin_thread_id"
    t.text "original_description"
    t.jsonb "output_files", default: [], null: false
    t.bigint "parent_task_id"
    t.boolean "pipeline_enabled", default: true
    t.jsonb "pipeline_log"
    t.string "pipeline_stage", default: "unstarted", null: false
    t.string "pipeline_type"
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
    t.string "routed_model"
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
    t.index ["agent_persona_id"], name: "index_tasks_on_agent_persona_id_partial", where: "(agent_persona_id IS NOT NULL)"
    t.index ["agent_session_id"], name: "index_tasks_on_agent_session_id_partial", where: "(agent_session_id IS NOT NULL)"
    t.index ["agent_session_key"], name: "index_tasks_on_agent_session_key_partial", where: "(agent_session_key IS NOT NULL)"
    t.index ["archived_at"], name: "index_tasks_on_archived_at", where: "(archived_at IS NOT NULL)"
    t.index ["assigned_to_agent"], name: "index_tasks_on_assigned_to_agent"
    t.index ["auto_pull_blocked"], name: "index_tasks_on_auto_pull_blocked"
    t.index ["blocked"], name: "index_tasks_on_blocked"
    t.index ["board_id", "archived_at"], name: "idx_tasks_board_archived"
    t.index ["board_id", "pipeline_stage"], name: "index_tasks_on_board_pipeline"
    t.index ["board_id", "status", "position"], name: "index_tasks_on_board_status_position"
    t.index ["board_id"], name: "index_tasks_on_board_id"
    t.index ["description"], name: "index_tasks_on_description_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["error_at"], name: "index_tasks_on_error_at", where: "(error_at IS NOT NULL)"
    t.index ["followup_task_id"], name: "index_tasks_on_followup_task_id"
    t.index ["followup_task_id"], name: "index_tasks_on_followup_task_id_partial", where: "(followup_task_id IS NOT NULL)"
    t.index ["last_run_id"], name: "index_tasks_on_last_run_id_partial", where: "(last_run_id IS NOT NULL)"
    t.index ["name"], name: "index_tasks_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["next_recurrence_at"], name: "index_tasks_on_next_recurrence_at"
    t.index ["nightly"], name: "index_tasks_on_nightly"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["pipeline_enabled"], name: "index_tasks_on_pipeline_enabled"
    t.index ["pipeline_stage"], name: "index_tasks_on_pipeline_stage"
    t.index ["position"], name: "index_tasks_on_position"
    t.index ["recurring"], name: "index_tasks_on_recurring"
    t.index ["review_status"], name: "index_tasks_on_review_status", where: "(review_status IS NOT NULL)"
    t.index ["review_type"], name: "index_tasks_on_review_type", where: "(review_type IS NOT NULL)"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["user_id", "assigned_to_agent", "status"], name: "index_tasks_on_user_agent_status"
    t.index ["user_id", "completed", "completed_at"], name: "idx_tasks_user_completed"
    t.index ["user_id", "priority", "position"], name: "idx_tasks_auto_runner_candidates", where: "((status = 1) AND (blocked = false) AND (agent_claimed_at IS NULL) AND (agent_session_id IS NULL) AND (agent_session_key IS NULL) AND (assigned_to_agent = true) AND (auto_pull_blocked = false))"
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
    t.index ["model", "created_at"], name: "index_token_usages_on_model_and_created_at"
    t.index ["model"], name: "index_token_usages_on_model"
    t.index ["session_key"], name: "index_token_usages_on_session_key"
    t.index ["task_id", "created_at"], name: "index_token_usages_on_task_id_and_created_at"
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
    t.boolean "notifications_enabled", default: true, null: false
    t.string "openclaw_gateway_token"
    t.string "openclaw_gateway_url"
    t.string "openclaw_hooks_token"
    t.string "password_digest"
    t.string "provider"
    t.string "telegram_bot_token"
    t.string "telegram_chat_id"
    t.string "theme", default: "default", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "webhook_notification_url"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["telegram_chat_id"], name: "index_users_on_telegram_chat_id_partial", where: "(telegram_chat_id IS NOT NULL)"
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direction", default: "incoming", null: false
    t.integer "duration_ms"
    t.string "endpoint", null: false
    t.string "error_message"
    t.string "event_type", null: false
    t.string "method", default: "POST", null: false
    t.jsonb "request_body", default: {}
    t.jsonb "request_headers", default: {}
    t.jsonb "response_body", default: {}
    t.integer "status_code"
    t.boolean "success", default: false, null: false
    t.bigint "task_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["direction"], name: "index_webhook_logs_on_direction"
    t.index ["event_type", "created_at"], name: "index_webhook_logs_on_event_type_and_created_at", order: { created_at: :desc }
    t.index ["success"], name: "index_webhook_logs_on_success", where: "(success = false)"
    t.index ["task_id"], name: "index_webhook_logs_on_task_id"
    t.index ["user_id", "created_at"], name: "index_webhook_logs_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_webhook_logs_on_user_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.jsonb "definition", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_workflows_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_messages", "tasks", column: "source_task_id", on_delete: :nullify
  add_foreign_key "agent_messages", "tasks", on_delete: :cascade
  add_foreign_key "agent_personas", "boards"
  add_foreign_key "agent_personas", "users"
  add_foreign_key "agent_test_recordings", "tasks"
  add_foreign_key "agent_test_recordings", "users"
  add_foreign_key "agent_transcripts", "task_runs"
  add_foreign_key "agent_transcripts", "tasks"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "audit_reports", "users"
  add_foreign_key "behavioral_interventions", "audit_reports"
  add_foreign_key "behavioral_interventions", "users"
  add_foreign_key "boards", "users"
  add_foreign_key "cost_snapshots", "users"
  add_foreign_key "factory_cycle_logs", "factory_loops"
  add_foreign_key "factory_loops", "users"
  add_foreign_key "feed_entries", "users"
  add_foreign_key "invite_codes", "users", column: "created_by_id"
  add_foreign_key "model_limits", "users"
  add_foreign_key "nightshift_missions", "users"
  add_foreign_key "nightshift_selections", "nightshift_missions"
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
  add_foreign_key "swarm_ideas", "users"
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
  add_foreign_key "webhook_logs", "tasks"
  add_foreign_key "webhook_logs", "users"
  add_foreign_key "workflows", "users"
end
