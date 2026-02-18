# frozen_string_literal: true

class AddGithubIntegrationToFactoryLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :factory_loops, :github_url, :string
    add_column :factory_loops, :github_pr_enabled, :boolean, default: false
    add_column :factory_loops, :github_pr_batch_size, :integer, default: 5
    add_column :factory_loops, :github_default_branch, :string, default: "main"
    add_column :factory_loops, :github_last_pr_at, :datetime
    add_column :factory_loops, :github_last_pr_url, :string

    add_index :factory_loops, :github_url, where: "github_url IS NOT NULL"
  end
end
