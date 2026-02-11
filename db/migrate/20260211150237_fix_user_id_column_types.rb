class FixUserIdColumnTypes < ActiveRecord::Migration[8.0]
  def up
    # tasks.user_id: integer → bigint + NOT NULL
    change_column :tasks, :user_id, :bigint, null: false

    # sessions.user_id: integer → bigint (already has NOT NULL)
    change_column :sessions, :user_id, :bigint, null: false
  end

  def down
    change_column :tasks, :user_id, :integer
    change_column :sessions, :user_id, :integer, null: false
  end
end
