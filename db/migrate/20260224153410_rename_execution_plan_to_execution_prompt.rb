# frozen_string_literal: true

class RenameExecutionPlanToExecutionPrompt < ActiveRecord::Migration[8.1]
  def change
    rename_column :tasks, :execution_plan, :execution_prompt
  end
end
