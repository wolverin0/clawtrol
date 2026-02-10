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

ActiveRecord::Schema[8.1].define(version: 2026_02_10_194704) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

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

  create_table "agent_thresholds", primary_key: "agent_name", id: { type: :string, limit: 100 }, force: :cascade do |t|
    t.boolean "enabled", default: true
    t.jsonb "thresholds", default: {}, null: false
    t.datetime "updated_at", precision: nil, default: -> { "now()" }
    t.string "updated_by", limit: 100
  end

  create_table "ai_conversations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "model", limit: 100
    t.string "provider", limit: 50, default: "ollama"
    t.string "title", limit: 255
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["created_at"], name: "idx_ai_conversations_created", order: :desc
  end

  create_table "ai_messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content", null: false
    t.uuid "conversation_id"
    t.timestamptz "created_at", default: -> { "now()" }
    t.jsonb "metadata", default: {}
    t.string "role", limit: 20, null: false
    t.index ["conversation_id"], name: "idx_ai_messages_conversation"
    t.index ["created_at"], name: "idx_ai_messages_created"
  end

  create_table "alerts", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.boolean "acknowledged", default: false
    t.timestamptz "acknowledged_at"
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "message"
    t.jsonb "metadata", default: {}
    t.string "severity", limit: 20, default: "info", null: false
    t.string "source", limit: 100, null: false
    t.string "title", limit: 255, null: false
    t.index ["acknowledged"], name: "idx_alerts_acknowledged"
    t.index ["created_at"], name: "idx_alerts_created", order: :desc
    t.index ["severity"], name: "idx_alerts_severity"
    t.index ["source"], name: "idx_alerts_source"
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

  create_table "backup_files", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "backup_type", limit: 50, null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "device_name", limit: 255, null: false
    t.string "file_name", limit: 255, null: false
    t.bigint "file_size_bytes"
    t.string "google_drive_file_id", limit: 255
    t.string "google_drive_folder_id", limit: 255
    t.index ["backup_type"], name: "idx_backup_files_type"
    t.index ["created_at"], name: "idx_backup_files_created", order: :desc
  end

  create_table "backup_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "backup_type", limit: 50, null: false
    t.timestamptz "completed_at"
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "destination", limit: 255
    t.string "device_name", limit: 255
    t.text "error_message"
    t.string "file_name", limit: 255
    t.bigint "file_size"
    t.bigint "file_size_bytes"
    t.string "google_drive_file_id", limit: 255
    t.string "google_drive_folder_id", limit: 255
    t.jsonb "metadata", default: {}
    t.timestamptz "started_at", default: -> { "now()" }
    t.string "status", limit: 20, default: "pending", null: false
    t.jsonb "validation_result"
    t.index ["backup_type"], name: "idx_backup_logs_type"
    t.index ["google_drive_file_id"], name: "idx_backup_logs_drive_file_id"
    t.index ["status"], name: "idx_backup_logs_status"
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

  create_table "body_metrics", id: :serial, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.jsonb "metadata"
    t.string "metric_type", limit: 20, null: false
    t.timestamptz "recorded_at", null: false
    t.string "source", limit: 50
    t.string "unit", limit: 10, null: false
    t.decimal "value", precision: 12, scale: 2, null: false
    t.index ["metric_type"], name: "idx_body_metrics_type"
    t.index ["recorded_at"], name: "idx_body_metrics_recorded", order: :desc
  end

  create_table "briefings", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content", null: false
    t.date "date", null: false
    t.jsonb "delivered_via", default: []
    t.timestamptz "generated_at", default: -> { "now()" }
    t.jsonb "sections", default: {}
    t.index ["date"], name: "idx_briefings_date", order: :desc
    t.unique_constraint ["date"], name: "briefings_date_key"
  end

  create_table "cached_data", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "data", null: false
    t.string "data_key", limit: 255, null: false
    t.timestamptz "expires_at"
    t.timestamptz "fetched_at", default: -> { "now()" }
    t.string "source_type", limit: 50, null: false
    t.timestamptz "updated_at", default: -> { "now()" }

    t.unique_constraint ["source_type", "data_key"], name: "cached_data_source_type_data_key_key"
  end

  create_table "claude_code_messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content", null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "role", limit: 50, null: false
    t.uuid "session_id"
    t.index ["created_at"], name: "idx_claude_messages_created"
    t.index ["session_id"], name: "idx_claude_messages_session"
  end

  create_table "claude_code_sessions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "ended_at"
    t.jsonb "metadata", default: {}
    t.text "project_path"
    t.string "session_name", limit: 255, null: false
    t.timestamptz "started_at", default: -> { "now()" }
    t.string "status", limit: 50, default: "active"
    t.index ["status"], name: "idx_claude_sessions_status"
  end

  create_table "communications", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "external_id", limit: 255
    t.boolean "is_read", default: false
    t.jsonb "metadata", default: {}
    t.boolean "needs_response", default: false
    t.text "preview"
    t.timestamptz "received_at"
    t.timestamptz "responded_at"
    t.string "sender_id", limit: 255
    t.string "sender_name", limit: 255
    t.string "source", limit: 50, null: false
    t.text "subject"
    t.index ["needs_response"], name: "idx_communications_needs_response"
    t.index ["received_at"], name: "idx_communications_received", order: :desc
    t.index ["sender_id"], name: "idx_communications_sender_id"
    t.index ["source"], name: "idx_communications_source"
    t.unique_constraint ["source", "external_id"], name: "communications_source_external_id_key"
  end

  create_table "daily_plan_actions", id: :serial, force: :cascade do |t|
    t.string "action", limit: 50, null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }
    t.string "item_id", limit: 255, null: false
    t.datetime "until_at", precision: nil
    t.index ["created_at"], name: "idx_daily_plan_actions_created"
    t.unique_constraint ["item_id", "action"], name: "daily_plan_actions_item_id_action_key"
  end

  create_table "dashboards", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.boolean "is_default", default: false
    t.jsonb "layout_config", default: {}
    t.string "name", limit: 255, default: "Main Dashboard", null: false
    t.timestamptz "updated_at", default: -> { "now()" }
    t.uuid "user_id"
    t.index ["user_id"], name: "idx_dashboards_user_id"
  end

  create_table "diet_adjustment_log", id: :serial, force: :cascade do |t|
    t.string "adjustment_type", limit: 50, null: false
    t.jsonb "after_value"
    t.jsonb "before_value"
    t.boolean "can_undo", default: true
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "description"
    t.string "source", limit: 20, null: false
    t.timestamptz "undo_until"
    t.index ["adjustment_type"], name: "idx_diet_adjustment_log_type"
    t.index ["can_undo", "undo_until"], name: "idx_diet_adjustment_log_undo"
    t.index ["created_at"], name: "idx_diet_adjustment_log_created", order: :desc
  end

  create_table "diet_meals", id: :serial, force: :cascade do |t|
    t.integer "calories", default: 0, null: false
    t.integer "carbs", default: 0, null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "day_type", limit: 20, null: false
    t.integer "fats", default: 0, null: false
    t.jsonb "foods", default: [], null: false
    t.string "meal_name", limit: 100, null: false
    t.integer "meal_number", null: false
    t.integer "phase_id", null: false
    t.integer "protein", default: 0, null: false
    t.string "time", limit: 5, null: false
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["day_type"], name: "idx_diet_meals_day_type"
    t.index ["meal_number"], name: "idx_diet_meals_number"
    t.index ["phase_id"], name: "idx_diet_meals_phase"
  end

  create_table "diet_phases", id: :serial, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "display_name", limit: 100, null: false
    t.date "end_date", null: false
    t.boolean "is_active", default: false
    t.boolean "is_optional", default: false
    t.string "name", limit: 50, null: false
    t.integer "sort_order", default: 0
    t.date "start_date", null: false
    t.integer "total_calories", default: 0
    t.integer "total_carbs", default: 0
    t.integer "total_fats", default: 0
    t.integer "total_protein", default: 0
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["is_active"], name: "idx_diet_phases_active"
    t.index ["name"], name: "idx_diet_phases_name"
  end

  create_table "diet_settings", id: :serial, force: :cascade do |t|
    t.string "key", limit: 100, null: false
    t.timestamptz "updated_at", default: -> { "now()" }
    t.jsonb "value", null: false

    t.unique_constraint ["key"], name: "diet_settings_key_key"
  end

  create_table "diet_supplements", id: :serial, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "dosage", limit: 50
    t.boolean "is_active", default: true
    t.string "name", limit: 100, null: false
    t.text "notes"
    t.integer "phase_id"
    t.string "timing", limit: 50, null: false
    t.index ["phase_id"], name: "idx_diet_supplements_phase"
    t.index ["timing"], name: "idx_diet_supplements_timing"
  end

  create_table "error_logs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.boolean "acknowledged", default: false
    t.timestamptz "acknowledged_at"
    t.string "app_name", limit: 255
    t.string "fingerprint", limit: 64
    t.timestamptz "first_seen_at", default: -> { "now()" }
    t.timestamptz "last_seen_at", default: -> { "now()" }
    t.string "level", limit: 20, default: "error", null: false
    t.text "message", null: false
    t.jsonb "metadata", default: {}
    t.integer "occurrence_count", default: 1
    t.timestamptz "resolved_at"
    t.string "source", limit: 100, null: false
    t.text "stack_trace"
    t.index ["app_name"], name: "idx_error_logs_app"
    t.index ["fingerprint"], name: "idx_error_logs_fingerprint"
    t.index ["last_seen_at"], name: "idx_error_logs_last_seen", order: :desc
    t.index ["source"], name: "idx_error_logs_source"
  end

  create_table "feed_items", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "content"
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "external_id", limit: 255
    t.boolean "is_read", default: false
    t.boolean "is_starred", default: false
    t.jsonb "metadata", default: {}
    t.timestamptz "published_at"
    t.string "source_name", limit: 255
    t.string "source_type", limit: 50, null: false
    t.text "title", null: false
    t.text "url"
    t.index ["is_read"], name: "idx_feed_items_read"
    t.index ["published_at"], name: "idx_feed_items_published", order: :desc
    t.index ["source_type"], name: "idx_feed_items_source"
    t.unique_constraint ["source_type", "external_id"], name: "feed_items_source_type_external_id_key"
  end

  create_table "jarvis_action_items", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Actionable items extracted from emails, messages, etc", force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.jsonb "details", default: {}
    t.timestamptz "due_date"
    t.string "item_type", limit: 50, comment: "Type: invoice, deadline, follow_up, meeting, reminder"
    t.text "resolution_note"
    t.timestamptz "resolved_at"
    t.string "source", limit: 50, null: false, comment: "Source: gmail, whatsapp, calendar, manual"
    t.text "source_id"
    t.text "source_url"
    t.string "status", limit: 20, default: "pending", comment: "Status: pending, surfaced, in_progress, resolved, ignored"
    t.timestamptz "surfaced_at"
    t.text "title", null: false
    t.timestamptz "updated_at", default: -> { "now()" }
    t.string "urgency", limit: 20, default: "normal", comment: "Urgency: low, normal, high, urgent"
    t.index ["created_at"], name: "idx_jarvis_action_items_pending", order: :desc, where: "((status)::text = 'pending'::text)"
    t.index ["due_date"], name: "idx_jarvis_action_items_due", where: "((due_date IS NOT NULL) AND ((status)::text = 'pending'::text))"
    t.index ["source", "source_id"], name: "idx_jarvis_action_items_source"
    t.index ["urgency"], name: "idx_jarvis_action_items_urgency", where: "((status)::text = 'pending'::text)"
  end

  create_table "jarvis_captures", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Raw message captures before processing into ideas/commands", force: :cascade do |t|
    t.decimal "confidence", precision: 3, scale: 2, comment: "LLM confidence in intent classification (0.00-1.00)"
    t.timestamptz "created_at", default: -> { "now()" }
    t.jsonb "history_json", default: [], comment: "Audit trail of routing/correction actions"
    t.string "intent_type", limit: 20, comment: "Detected intent: idea, task, command, question, chat"
    t.decimal "margin", precision: 3, scale: 2, comment: "Confidence margin to second-best intent (0.00-1.00)"
    t.text "normalized"
    t.timestamptz "processed_at"
    t.text "raw_text", null: false
    t.string "source", limit: 50, default: "telegram"
    t.text "source_message_id"
    t.timestamptz "ts", default: -> { "now()" }
    t.index ["created_at"], name: "idx_jarvis_captures_unprocessed", order: :desc, where: "(processed_at IS NULL)"
    t.index ["intent_type"], name: "idx_jarvis_captures_intent", where: "(intent_type IS NOT NULL)"
    t.index ["source", "ts"], name: "idx_jarvis_captures_source", order: { ts: :desc }
    t.index ["source_message_id"], name: "idx_jarvis_captures_source_message_id"
  end

  create_table "jarvis_claude_tasks", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Complex tasks delegated to Claude Code for execution", force: :cascade do |t|
    t.timestamptz "approved_at"
    t.string "approved_by", limit: 100
    t.timestamptz "completed_at"
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "error"
    t.integer "exit_code"
    t.jsonb "file_changes", default: [], comment: "Array of file changes detected from Claude output"
    t.text "output"
    t.integer "pid", comment: "Process ID of the running Claude process"
    t.string "priority", limit: 20, default: "normal"
    t.text "project_path", null: false, comment: "Working directory for Claude execution"
    t.text "prompt", null: false, comment: "The task prompt sent to Claude"
    t.timestamptz "requested_at", default: -> { "now()" }
    t.string "requested_by", limit: 100, null: false
    t.timestamptz "started_at"
    t.string "status", limit: 20, default: "queued", comment: "Task lifecycle: queued → running → completed → approved/rejected"
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["completed_at"], name: "idx_jarvis_claude_tasks_approval", order: :desc, where: "((status)::text = 'completed'::text)"
    t.index ["file_changes"], name: "idx_jarvis_claude_tasks_files", using: :gin
    t.index ["priority", "requested_at"], name: "idx_jarvis_claude_tasks_queued", where: "((status)::text = 'queued'::text)"
    t.index ["requested_by", "created_at"], name: "idx_jarvis_claude_tasks_requester", order: { created_at: :desc }
    t.index ["started_at"], name: "idx_jarvis_claude_tasks_running", order: :desc, where: "((status)::text = 'running'::text)"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'normal'::character varying, 'high'::character varying, 'urgent'::character varying]::text[])", name: "jarvis_claude_tasks_priority_check"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying, 'running'::character varying, 'completed'::character varying, 'approved'::character varying, 'rejected'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "jarvis_claude_tasks_status_check"
  end

  create_table "jarvis_commands", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Executed commands with full audit trail", force: :cascade do |t|
    t.uuid "capture_id"
    t.string "command_slug", limit: 100, null: false, comment: "Registered command identifier"
    t.text "confirmation_reason", comment: "Reason provided for high-risk commands"
    t.timestamptz "confirmation_sent_at"
    t.timestamptz "confirmed_at"
    t.string "confirmed_by", limit: 100, comment: "Who confirmed the command (for risky commands)"
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "error"
    t.timestamptz "executed_at"
    t.boolean "is_dry_run", default: false, comment: "Whether this was a dry-run execution"
    t.jsonb "params", default: {}
    t.string "requested_by", limit: 100, default: "unknown", comment: "Who requested the command (user ID or system)"
    t.jsonb "result"
    t.string "risk_level", limit: 20, default: "low", comment: "Risk: read_only, low, medium, high, critical"
    t.string "status", limit: 20, default: "pending", comment: "Status: pending, awaiting_confirmation, confirmed, executing, completed, failed, cancelled"
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["capture_id"], name: "idx_jarvis_commands_capture_id"
    t.index ["command_slug", "created_at"], name: "idx_jarvis_commands_slug", order: { created_at: :desc }
    t.index ["created_at"], name: "idx_jarvis_commands_pending", order: :desc, where: "((status)::text = 'pending'::text)"
    t.index ["status"], name: "idx_jarvis_commands_status"
  end

  create_table "jarvis_ideas", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Ideas extracted from captures, routed to projects", force: :cascade do |t|
    t.uuid "capture_id"
    t.string "category", limit: 50, default: "misc"
    t.text "content", null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "last_surfaced_at"
    t.integer "priority", default: 3, comment: "Priority 1-5 (1=highest)"
    t.decimal "project_confidence", precision: 3, scale: 2, comment: "LLM confidence in project match"
    t.uuid "project_id"
    t.string "status", limit: 20, default: "inbox", comment: "Status: inbox, triaged, in_progress, done, archived"
    t.string "summary", limit: 500
    t.integer "surfaced_count", default: 0, comment: "Times surfaced in briefings (for stale detection)"
    t.text "tags", default: [], array: true
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["capture_id"], name: "idx_jarvis_ideas_capture_id"
    t.index ["category"], name: "idx_jarvis_ideas_category"
    t.index ["created_at"], name: "idx_jarvis_ideas_inbox", order: :desc, where: "((status)::text = 'inbox'::text)"
    t.index ["project_id"], name: "idx_jarvis_ideas_project", where: "(project_id IS NOT NULL)"
    t.index ["tags"], name: "idx_jarvis_ideas_tags", using: :gin
    t.check_constraint "priority >= 1 AND priority <= 5", name: "jarvis_ideas_priority_check"
  end

  create_table "jarvis_projects", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Mirror of local development projects in ~/Py Apps folder", force: :cascade do |t|
    t.boolean "active", default: true
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "description"
    t.text "keywords", default: [], comment: "Keywords for project matching from README, package.json, etc", array: true
    t.timestamptz "last_scan"
    t.string "name", limit: 255, null: false
    t.text "path", null: false
    t.string "slug", limit: 100, null: false, comment: "URL-safe identifier derived from folder name"
    t.jsonb "tech_stack", default: [], comment: "Detected technologies: {name, version, source}[]"
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["active"], name: "idx_jarvis_projects_active", where: "(active = true)"
    t.index ["keywords"], name: "idx_jarvis_projects_keywords", using: :gin
    t.index ["slug"], name: "idx_jarvis_projects_slug"
    t.index ["tech_stack"], name: "idx_jarvis_projects_tech_stack", using: :gin
    t.unique_constraint ["slug"], name: "jarvis_projects_slug_key"
  end

  create_table "metrics_history", id: :serial, force: :cascade do |t|
    t.jsonb "dimensions", default: {}
    t.text "metric_name", null: false
    t.decimal "metric_value", null: false
    t.timestamptz "recorded_at", default: -> { "now()" }, null: false
    t.index ["metric_name", "recorded_at"], name: "idx_metrics_history_lookup", order: { recorded_at: :desc }
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

  create_table "network_metrics", id: :uuid, default: -> { "gen_random_uuid()" }, comment: "Time-series network metrics from agents. Auto-cleanup: DELETE WHERE recorded_at < NOW() - INTERVAL '30 days'", force: :cascade do |t|
    t.string "metric_source", limit: 100, null: false, comment: "Identifier: router IP, agent name, host IP, etc."
    t.string "metric_type", limit: 50, null: false, comment: "Types: router_health, traffic, host_ping, wisp_health, dude_device, dude_link, rogue_ip"
    t.timestamptz "recorded_at", default: -> { "now()" }
    t.jsonb "value", null: false, comment: "JSON payload varies by metric_type."
    t.index ["metric_source", "recorded_at"], name: "idx_network_metrics_source_time", order: { recorded_at: :desc }
    t.index ["metric_type", "metric_source", "recorded_at"], name: "idx_network_metrics_type_source", order: { recorded_at: :desc }
    t.index ["metric_type", "recorded_at"], name: "idx_network_metrics_type_time", order: { recorded_at: :desc }
  end

  create_table "network_sites", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.integer "customer_count", default: 0
    t.timestamptz "last_checked_at"
    t.jsonb "metadata", default: {}
    t.string "site_code", limit: 50
    t.string "site_name", limit: 255, null: false
    t.string "status", limit: 50, default: "unknown"
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["status"], name: "idx_network_sites_status"
    t.unique_constraint ["site_code"], name: "network_sites_site_code_key"
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

  create_table "pgmigrations", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.datetime "run_on", precision: nil, null: false
  end

  create_table "push_subscriptions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "auth", null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "device_name", limit: 255
    t.text "endpoint", null: false
    t.boolean "is_active", default: true
    t.timestamptz "last_used_at", default: -> { "now()" }
    t.text "p256dh", null: false
    t.jsonb "preferences", default: {"alerts"=>true, "errors"=>true, "daily_briefing"=>false, "claude_sessions"=>true}
    t.uuid "user_id"
    t.index ["is_active"], name: "idx_push_subscriptions_active"
    t.index ["user_id"], name: "idx_push_subscriptions_user"
    t.unique_constraint ["endpoint"], name: "push_subscriptions_endpoint_key"
  end

  create_table "quick_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "category", limit: 100
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "icon", limit: 100
    t.boolean "is_active", default: true
    t.timestamptz "last_checked_at"
    t.string "last_status", limit: 20
    t.string "name", limit: 255, null: false
    t.integer "sort_order", default: 0
    t.timestamptz "updated_at", default: -> { "now()" }
    t.text "url", null: false
    t.uuid "user_id"
    t.index ["category"], name: "idx_quick_links_category"
    t.index ["user_id"], name: "idx_quick_links_user"
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

  create_table "service_health_logs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "checked_at", default: -> { "now()" }
    t.text "error_message"
    t.jsonb "metadata", default: {}
    t.integer "response_time_ms"
    t.string "service_name", limit: 100, null: false
    t.string "status", limit: 20, default: "unknown", null: false
    t.index ["checked_at"], name: "idx_service_health_logs_checked_at", order: :desc
    t.index ["service_name"], name: "idx_service_health_logs_service_name"
    t.index ["status"], name: "idx_service_health_logs_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
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
    t.integer "confidence", default: 0, null: false
    t.integer "context_usage_percent"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.integer "effort", default: 0, null: false
    t.datetime "error_at"
    t.text "error_message"
    t.bigint "followup_task_id"
    t.integer "impact", default: 0, null: false
    t.boolean "last_needs_follow_up"
    t.datetime "last_outcome_at"
    t.string "last_recommended_action"
    t.uuid "last_run_id"
    t.string "model"
    t.string "name"
    t.datetime "next_recurrence_at"
    t.boolean "nightly", default: false, null: false
    t.integer "nightly_delay_hours"
    t.integer "original_position"
    t.jsonb "output_files", default: [], null: false
    t.bigint "parent_task_id"
    t.integer "position"
    t.integer "priority", default: 0, null: false
    t.integer "reach", default: 0, null: false
    t.string "recurrence_rule"
    t.time "recurrence_time"
    t.boolean "recurring", default: false, null: false
    t.integer "retry_count", default: 0
    t.jsonb "review_config", default: {}
    t.jsonb "review_result", default: {}
    t.string "review_status"
    t.string "review_type"
    t.integer "run_count", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "suggested_followup"
    t.string "tags", default: [], array: true
    t.datetime "updated_at", null: false
    t.integer "user_id"
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
    t.index ["error_at"], name: "index_tasks_on_error_at", where: "(error_at IS NOT NULL)"
    t.index ["followup_task_id"], name: "index_tasks_on_followup_task_id"
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

  create_table "transactions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.string "category", limit: 100
    t.string "counterparty_name", limit: 255
    t.timestamptz "created_at", default: -> { "now()" }
    t.string "currency", limit: 10, default: "ARS"
    t.text "description"
    t.string "external_id", limit: 255, null: false
    t.jsonb "raw_data"
    t.string "source", limit: 50, default: "mercadopago"
    t.timestamptz "transaction_date", null: false
    t.string "type", limit: 50, null: false
    t.index ["category"], name: "idx_transactions_category"
    t.index ["transaction_date"], name: "idx_transactions_date", order: :desc
    t.index ["type"], name: "idx_transactions_type"
    t.unique_constraint ["external_id"], name: "transactions_external_id_key"
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
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  create_table "whatsapp_archived_chats", id: :serial, force: :cascade do |t|
    t.string "chat_id", limit: 100, null: false
    t.string "chat_name", limit: 255, null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }
    t.datetime "first_archived", precision: nil, default: -> { "now()" }
    t.boolean "is_group", default: false
    t.datetime "last_archived", precision: nil, default: -> { "now()" }
    t.datetime "last_message_at", precision: nil
    t.integer "message_count", default: 0
    t.text "profile_pic_url"
    t.datetime "updated_at", precision: nil, default: -> { "now()" }

    t.unique_constraint ["chat_id"], name: "whatsapp_archived_chats_chat_id_key"
  end

  create_table "whatsapp_archived_messages", id: :serial, force: :cascade do |t|
    t.datetime "archived_at", precision: nil, default: -> { "now()" }
    t.text "body"
    t.string "chat_id", limit: 100, null: false
    t.boolean "from_me", default: false
    t.boolean "has_media", default: false
    t.string "message_id", limit: 100, null: false
    t.string "message_type", limit: 50, default: "chat"
    t.string "sender_id", limit: 100
    t.string "sender_name", limit: 255
    t.datetime "timestamp", precision: nil, null: false
    t.index "to_tsvector('spanish'::regconfig, body)", name: "idx_archived_messages_body", using: :gin
    t.index ["chat_id"], name: "idx_archived_messages_chat_id"
    t.index ["from_me"], name: "idx_archived_messages_from_me"
    t.index ["message_type"], name: "idx_archived_messages_type"
    t.index ["sender_id"], name: "idx_archived_messages_sender"
    t.index ["timestamp"], name: "idx_archived_messages_timestamp", order: :desc
    t.unique_constraint ["message_id"], name: "whatsapp_archived_messages_message_id_key"
  end

  create_table "whatsapp_chats", id: :text, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.boolean "is_group", default: false
    t.timestamptz "last_message_at"
    t.text "name"
    t.text "phone_number"
    t.text "profile_picture_url"
    t.integer "unread_count", default: 0
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["last_message_at"], name: "idx_whatsapp_chats_last_message", order: :desc
  end

  create_table "whatsapp_media", id: :serial, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.text "file_path", null: false
    t.integer "file_size"
    t.text "message_id", null: false
    t.text "mime_type"
    t.text "thumbnail_path"
  end

  create_table "whatsapp_messages", id: :text, force: :cascade do |t|
    t.text "body"
    t.text "chat_id", null: false
    t.timestamptz "created_at", default: -> { "now()" }
    t.boolean "from_me", null: false
    t.boolean "has_media", default: false
    t.boolean "is_forwarded", default: false
    t.boolean "is_starred", default: false
    t.text "media_filename"
    t.text "media_mime_type"
    t.text "media_url"
    t.text "quoted_message_id"
    t.jsonb "raw_data"
    t.text "sender_id"
    t.text "sender_name"
    t.timestamptz "timestamp", null: false
    t.text "type", default: "chat", null: false
    t.index ["chat_id"], name: "idx_whatsapp_messages_chat_id"
    t.index ["timestamp"], name: "idx_whatsapp_messages_timestamp", order: :desc
    t.index ["type"], name: "idx_whatsapp_messages_type"
  end

  create_table "whatsapp_sessions", id: :text, default: "default", force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "last_connected_at"
    t.text "phone_number"
    t.text "qr_code"
    t.jsonb "session_data"
    t.text "status", default: "disconnected", null: false
    t.timestamptz "updated_at", default: -> { "now()" }
  end

  create_table "widget_instances", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }
    t.uuid "dashboard_id"
    t.boolean "is_visible", default: true
    t.jsonb "position", default: {"h"=>2, "w"=>2, "x"=>0, "y"=>0}, null: false
    t.jsonb "settings", default: {}
    t.string "title", limit: 255
    t.timestamptz "updated_at", default: -> { "now()" }
    t.string "widget_type", limit: 100, null: false
    t.index ["dashboard_id"], name: "idx_widget_instances_dashboard_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_personas", "users"
  add_foreign_key "ai_messages", "ai_conversations", column: "conversation_id", name: "ai_messages_conversation_id_fkey", on_delete: :cascade
  add_foreign_key "api_tokens", "users"
  add_foreign_key "boards", "users"
  add_foreign_key "claude_code_messages", "claude_code_sessions", column: "session_id", name: "claude_code_messages_session_id_fkey", on_delete: :cascade
  add_foreign_key "diet_meals", "diet_phases", column: "phase_id", name: "diet_meals_phase_id_fkey", on_delete: :cascade
  add_foreign_key "diet_supplements", "diet_phases", column: "phase_id", name: "diet_supplements_phase_id_fkey", on_delete: :cascade
  add_foreign_key "jarvis_commands", "jarvis_captures", column: "capture_id", name: "jarvis_commands_capture_id_fkey", on_delete: :nullify
  add_foreign_key "jarvis_ideas", "jarvis_captures", column: "capture_id", name: "jarvis_ideas_capture_id_fkey", on_delete: :nullify
  add_foreign_key "jarvis_ideas", "jarvis_projects", column: "project_id", name: "jarvis_ideas_project_id_fkey", on_delete: :nullify
  add_foreign_key "model_limits", "users"
  add_foreign_key "notifications", "tasks"
  add_foreign_key "notifications", "users"
  add_foreign_key "openclaw_integration_statuses", "users"
  add_foreign_key "runner_leases", "tasks"
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
  add_foreign_key "whatsapp_archived_messages", "whatsapp_archived_chats", column: "chat_id", primary_key: "chat_id", name: "whatsapp_archived_messages_chat_id_fkey", on_delete: :cascade
  add_foreign_key "whatsapp_media", "whatsapp_messages", column: "message_id", name: "whatsapp_media_message_id_fkey", on_delete: :cascade
  add_foreign_key "whatsapp_messages", "whatsapp_chats", column: "chat_id", name: "whatsapp_messages_chat_id_fkey", on_delete: :cascade
  add_foreign_key "widget_instances", "dashboards", name: "widget_instances_dashboard_id_fkey", on_delete: :cascade
end
