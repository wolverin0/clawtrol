class AddReviewColumnsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :review_type, :string      # null, "command", "debate"
    add_column :tasks, :review_config, :jsonb, default: {}
    add_column :tasks, :review_result, :jsonb, default: {}
    add_column :tasks, :review_status, :string    # pending, running, passed, failed

    add_index :tasks, :review_type, where: "review_type IS NOT NULL"
    add_index :tasks, :review_status, where: "review_status IS NOT NULL"
  end
end
