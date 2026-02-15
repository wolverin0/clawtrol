# frozen_string_literal: true

class AddIndexesForCommonQueries < ActiveRecord::Migration[8.1]
  def change
    # Tasks: completed queries by user
    add_index :tasks, [:user_id, :completed, :completed_at], name: "idx_tasks_user_completed"
    
    # Tasks: board with archived filter
    add_index :tasks, [:board_id, :archived_at], name: "idx_tasks_board_archived"
    
    # AgentTranscripts: cleanup by created_at
    add_index :agent_transcripts, [:created_at], name: "idx_agent_transcripts_cleanup"
    
    # Notifications: inbox queries (unread first)
    add_index :notifications, [:user_id, :read, :created_at], name: "idx_notifications_inbox"
    
    # FactoryCycleLogs: user lookup
    add_index :factory_cycle_logs, [:user_id], name: "idx_cycle_logs_user"
  end
end
