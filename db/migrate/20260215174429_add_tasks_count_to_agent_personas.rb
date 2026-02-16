# frozen_string_literal: true

class AddTasksCountToAgentPersonas < ActiveRecord::Migration[8.2]
  def change
    unless column_exists?(:agent_personas, :tasks_count)
      add_column :agent_personas, :tasks_count, :integer, default: 0, null: false
    end

    return unless column_exists?(:agent_personas, :tasks_count)

    # Backfill existing counts
    AgentPersona.reset_column_information
    AgentPersona.find_each do |persona|
      AgentPersona.where(id: persona.id).update_all(tasks_count: persona.tasks.count)
    end
  end
end
