class DropCommentsAndAddActorInfoToActivities < ActiveRecord::Migration[8.1]
  def change
    # Drop comments table
    drop_table :comments, if_exists: true

    # Remove comments_count from tasks
    remove_column :tasks, :comments_count, :integer, if_exists: true

    # Remove comment-related columns from tasks
    remove_column :tasks, :needs_agent_reply, :boolean, if_exists: true
    remove_column :tasks, :last_agent_read_at, :datetime, if_exists: true

    # Add actor info to activities for showing agent name/emoji
    add_column :task_activities, :actor_type, :string
    add_column :task_activities, :actor_name, :string
    add_column :task_activities, :actor_emoji, :string
  end
end
