class AddArchivedStatusToTasks < ActiveRecord::Migration[8.1]
  def change
    # Add archived status (value 5) to the enum
    # Current: inbox: 0, up_next: 1, in_progress: 2, in_review: 3, done: 4
    # No column change needed - just update the enum in the model
    
    # Add archived_at timestamp for tracking when tasks were archived
    add_column :tasks, :archived_at, :datetime
    add_index :tasks, :archived_at, where: "archived_at IS NOT NULL"
  end
end
