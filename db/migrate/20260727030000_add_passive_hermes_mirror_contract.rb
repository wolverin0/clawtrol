# frozen_string_literal: true

class AddPassiveHermesMirrorContract < ActiveRecord::Migration[8.1]
  DIRECT_CONTROL_CREDENTIAL_COLUMNS = %i[
    openclaw_gateway_token
    openclaw_hooks_token
    hermes_gateway_token
    hermes_hooks_token
  ].freeze

  def up
    add_column :api_tokens, :scopes, :jsonb, null: false, default: []
    add_column :api_tokens, :revoked_at, :datetime
    add_index :api_tokens, :revoked_at

    add_column :task_runs, :external_source_key, :string
    add_index :task_runs, :external_source_key, unique: true,
      where: "external_source_key IS NOT NULL"

    add_index :tasks, %i[user_id origin_session_key],
      unique: true,
      name: "idx_tasks_user_hermes_origin_key",
      where: "origin_session_key LIKE 'hermes:%'"

    clear_direct_control_credentials
  end

  def down
    remove_index :tasks, name: "idx_tasks_user_hermes_origin_key"
    remove_index :task_runs, :external_source_key
    remove_column :task_runs, :external_source_key
    remove_index :api_tokens, :revoked_at
    remove_column :api_tokens, :revoked_at
    remove_column :api_tokens, :scopes
  end

  private

  def clear_direct_control_credentials
    columns = DIRECT_CONTROL_CREDENTIAL_COLUMNS.select { |column| column_exists?(:users, column) }
    return if columns.empty?

    values = columns.index_with { nil }
    update "UPDATE users SET #{values.keys.map { |column| "#{quote_column_name(column)} = NULL" }.join(', ')}"
  end
end
