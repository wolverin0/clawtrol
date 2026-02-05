class CreateModelLimits < ActiveRecord::Migration[8.1]
  def change
    create_table :model_limits do |t|
      t.references :user, null: false, foreign_key: true
      t.string :model_name, null: false
      t.boolean :limited, default: false, null: false
      t.datetime :resets_at
      t.text :error_message
      t.datetime :last_error_at

      t.timestamps
    end

    add_index :model_limits, [:user_id, :model_name], unique: true
    add_index :model_limits, :resets_at, where: "limited = true"
  end
end
