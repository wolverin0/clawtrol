# frozen_string_literal: true

class AddRemainingFkIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # tasks.board_id — heavily queried (14 references across controllers/models)
    add_index :tasks, :board_id, algorithm: :concurrently, if_not_exists: true

    # tasks.agent_persona_id — queried in persona dashboards and task listings
    add_index :tasks, :agent_persona_id, algorithm: :concurrently, if_not_exists: true,
              where: "agent_persona_id IS NOT NULL",
              name: "index_tasks_on_agent_persona_id_partial"

    # tasks.followup_task_id — FK for task chains/follow-ups
    add_index :tasks, :followup_task_id, algorithm: :concurrently, if_not_exists: true,
              where: "followup_task_id IS NOT NULL",
              name: "index_tasks_on_followup_task_id_partial"

    # nightshift_selections.nightshift_mission_id — queried with uniqueness scope
    add_index :nightshift_selections, :nightshift_mission_id, algorithm: :concurrently, if_not_exists: true
  end
end
