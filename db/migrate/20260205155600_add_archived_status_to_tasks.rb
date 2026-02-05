class AddArchivedStatusToTasks < ActiveRecord::Migration[8.0]
  def change
    # The status enum is stored as an integer in Rails, so no schema change needed.
    # The value 5 for 'archived' is handled by the enum definition in the model.
    # This migration serves as documentation that the archived status was added.
  end
end
