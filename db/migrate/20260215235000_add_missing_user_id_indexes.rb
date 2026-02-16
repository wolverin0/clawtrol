# frozen_string_literal: true

class AddMissingUserIdIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index_if_column_exists(:agent_transcripts, :user_id)
    add_index_if_column_exists(:task_activities, :user_id)
    add_index_if_column_exists(:webhook_logs, :user_id)
  end

  private

  def add_index_if_column_exists(table_name, column_name)
    return unless table_exists?(table_name)
    return unless column_exists?(table_name, column_name)

    add_index table_name, column_name, algorithm: :concurrently, if_not_exists: true
  end
end
