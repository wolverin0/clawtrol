# frozen_string_literal: true

class AddPipelineColumnsToTasks < ActiveRecord::Migration[8.1]
  def change
    # Pipeline columns on tasks
    add_column :tasks, :pipeline_stage, :string, default: nil
    add_column :tasks, :pipeline_type, :string, default: nil
    add_column :tasks, :routed_model, :string, default: nil
    add_column :tasks, :compiled_prompt, :text, default: nil
    add_column :tasks, :agent_context, :jsonb, default: nil
    add_column :tasks, :pipeline_enabled, :boolean, default: false
    add_column :tasks, :pipeline_log, :jsonb, default: nil

    add_index :tasks, :pipeline_stage
    add_index :tasks, :pipeline_enabled

    # Pipeline toggle on boards
    add_column :boards, :pipeline_enabled, :boolean, default: false

    # Pipeline type hint on task_templates
    add_column :task_templates, :pipeline_type, :string, default: nil
  end
end
