class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.string :event_type
      t.text :message
      t.datetime :read_at

      t.timestamps
    end
  end
end
