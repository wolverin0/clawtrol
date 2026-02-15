# frozen_string_literal: true

class AddMissingForeignKeyIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # swarm_ideas.board_id — FK used in scoped queries
    add_index :swarm_ideas, :board_id, algorithm: :concurrently, if_not_exists: true

    # task_runs.openclaw_session_id — used in task_outcome_service writes
    add_index :task_runs, :openclaw_session_id, algorithm: :concurrently, if_not_exists: true

    # users.telegram_chat_id — used by Telegram Mini App auth lookup
    add_index :users, :telegram_chat_id, algorithm: :concurrently, if_not_exists: true,
              where: "telegram_chat_id IS NOT NULL",
              name: "index_users_on_telegram_chat_id_partial"

    # tasks.last_run_id — FK reference to task_runs
    add_index :tasks, :last_run_id, algorithm: :concurrently, if_not_exists: true,
              where: "last_run_id IS NOT NULL",
              name: "index_tasks_on_last_run_id_partial"
  end
end
