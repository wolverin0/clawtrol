# frozen_string_literal: true

class AddIndexesForCommonQueries < ActiveRecord::Migration[8.1]
  def change
    # Tasks: completed queries by user
    add_index :tasks, [:user_id, :completed, :completed_at], name: "idx_tasks_user_completed", if_not_exists: true

    # Tasks: board with archived filter
    add_index :tasks, [:board_id, :archived_at], name: "idx_tasks_board_archived", if_not_exists: true

    # AgentTranscripts: cleanup by created_at
    add_index :agent_transcripts, [:created_at], name: "idx_agent_transcripts_cleanup", if_not_exists: true

    # Notifications: inbox queries (unread first) - uses read_at column
    add_index :notifications, [:user_id, :read_at, :created_at], name: "idx_notifications_inbox", if_not_exists: true

    # FactoryCycleLogs: loop lookup (user is via factory_loop.user)
    add_index :factory_cycle_logs, [:factory_loop_id, :created_at], name: "idx_cycle_logs_loop_created", if_not_exists: true
  end
end
