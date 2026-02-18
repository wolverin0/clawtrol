# frozen_string_literal: true

class CreateBoardRoadmapTaskLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :board_roadmap_task_links do |t|
      t.references :board_roadmap, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.string :item_key, null: false
      t.text :item_text, null: false

      t.timestamps
    end

    add_index :board_roadmap_task_links, [:board_roadmap_id, :item_key], unique: true, name: "idx_roadmap_task_links_unique_item"
    add_index :board_roadmap_task_links, [:board_roadmap_id, :task_id], unique: true, name: "idx_roadmap_task_links_unique_task"
  end
end
