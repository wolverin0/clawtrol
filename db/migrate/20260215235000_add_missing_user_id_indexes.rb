# frozen_string_literal: true

class AddMissingUserIdIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # agent_transcripts.user_id - frequently filtered by user, no index exists
    add_index :agent_transcripts, :user_id, algorithm: :concurrently, if_not_exists: true

    # task_activities.user_id - user activity queries
    add_index :task_activities, :user_id, algorithm: :concurrently, if_not_exists: true

    # webhook_logs.user_id - user webhook history queries
    add_index :webhook_logs, :user_id, algorithm: :concurrently, if_not_exists: true
  end
end
