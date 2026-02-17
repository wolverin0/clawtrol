# frozen_string_literal: true

class CreateFactoryFindingPatterns < ActiveRecord::Migration[8.1]
  def change
    create_table :factory_finding_patterns do |t|
      t.string :pattern_hash, null: false
      t.text :description, null: false
      t.string :category
      t.integer :dismiss_count, default: 0
      t.boolean :suppressed, default: false
      t.references :factory_loop, foreign_key: true

      t.timestamps
    end

    add_index :factory_finding_patterns,
              %i[factory_loop_id pattern_hash],
              unique: true,
              name: "idx_finding_patterns_loop_hash"
    add_index :factory_finding_patterns, :suppressed
  end
end
