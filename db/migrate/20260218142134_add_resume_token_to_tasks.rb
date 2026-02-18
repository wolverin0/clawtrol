class AddResumeTokenToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :resume_token, :string
    add_column :tasks, :lobster_status, :string
    add_column :tasks, :lobster_pipeline, :string
  end
end
