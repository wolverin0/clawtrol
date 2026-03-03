# frozen_string_literal: true

class CreateBoardProjectFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :board_project_files do |t|
      t.references :board, null: false, foreign_key: true, index: true
      t.string :file_path, null: false
      t.string :label
      t.string :file_type, default: "auto"
      t.boolean :pinned, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :board_project_files, [ :board_id, :file_path ], unique: true, name: "idx_board_project_files_unique"
  end
end
