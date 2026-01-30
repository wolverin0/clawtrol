class BackfillTaskCreationActivities < ActiveRecord::Migration[8.1]
  def up
    Task.find_each do |task|
      TaskActivity.create!(
        task: task,
        user: task.user,
        action: "created",
        source: "web",
        created_at: task.created_at,
        updated_at: task.created_at
      )
    end
  end

  def down
    TaskActivity.where(action: "created").delete_all
  end
end
