class CreateBoards < ActiveRecord::Migration[8.1]
  def change
    create_table :boards do |t|
      t.string :name, null: false
      t.string :icon, default: "📋"
      t.string :color, default: "gray"
      t.references :user, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :boards, [:user_id, :position]
  end
end
