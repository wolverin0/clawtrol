# frozen_string_literal: true

class AddCompoundIndexToTokenUsages < ActiveRecord::Migration[8.0]
  def change
    # Optimizes the analytics cost_by_task query:
    #   TokenUsage.where("created_at >= ?", 30.days.ago).joins(:task).group("tasks.id")
    # Also helps daily_usage and by_date_range scopes that filter on created_at + task_id
    add_index :token_usages, [:task_id, :created_at], name: "index_token_usages_on_task_id_and_created_at"

    # Optimizes model + date range queries (cost breakdown by model over time)
    add_index :token_usages, [:model, :created_at], name: "index_token_usages_on_model_and_created_at"
  end
end
