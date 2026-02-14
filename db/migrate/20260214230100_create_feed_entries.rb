# frozen_string_literal: true

class CreateFeedEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :feed_name, null: false        # e.g. "HackerNews", "ArsTechnica", "RailsWeekly"
      t.string :feed_url                       # feed source URL
      t.string :title, null: false
      t.string :url, null: false
      t.string :author
      t.text :summary                          # AI-generated or excerpt
      t.text :content                          # full content if fetched
      t.float :relevance_score                 # 0.0-1.0, set by n8n or AI
      t.string :tags, array: true, default: [] # topic tags
      t.integer :status, default: 0, null: false # 0=unread, 1=read, 2=saved, 3=dismissed
      t.datetime :published_at
      t.datetime :read_at

      t.timestamps
    end

    add_index :feed_entries, [:user_id, :status]
    add_index :feed_entries, [:user_id, :feed_name]
    add_index :feed_entries, [:user_id, :published_at], order: { published_at: :desc }
    add_index :feed_entries, [:user_id, :relevance_score], order: { relevance_score: :desc }
    add_index :feed_entries, :url, unique: true
  end
end
