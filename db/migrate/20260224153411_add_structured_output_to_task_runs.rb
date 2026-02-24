# frozen_string_literal: true

class AddStructuredOutputToTaskRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :task_runs, :prompt_used, :text
    add_column :task_runs, :agent_output, :text
    add_column :task_runs, :agent_activity_md, :text
    add_column :task_runs, :follow_up_prompt, :text
  end
end
