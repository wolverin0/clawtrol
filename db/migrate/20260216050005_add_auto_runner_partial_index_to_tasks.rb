# frozen_string_literal: true

class AddAutoRunnerPartialIndexToTasks < ActiveRecord::Migration[8.0]
  def change
    # Covers the hot path in AgentAutoRunnerService#runnable_up_next_task_for:
    #   user.tasks
    #     .where(status: :up_next, blocked: false, agent_claimed_at: nil,
    #            agent_session_id: nil, agent_session_key: nil,
    #            assigned_to_agent: true, auto_pull_blocked: false)
    #     .order(priority: :desc, position: :asc)
    #
    # The partial WHERE clause eliminates most rows; the covering columns
    # let Postgres do a fast index scan + sort on priority/position.
    add_index :tasks,
              [:user_id, :priority, :position],
              name: "idx_tasks_auto_runner_candidates",
              where: <<~SQL.squish
                status = 1
                AND blocked = false
                AND agent_claimed_at IS NULL
                AND agent_session_id IS NULL
                AND agent_session_key IS NULL
                AND assigned_to_agent = true
                AND auto_pull_blocked = false
              SQL
  end
end
