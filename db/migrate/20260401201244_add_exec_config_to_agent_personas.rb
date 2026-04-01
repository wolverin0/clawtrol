class AddExecConfigToAgentPersonas < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_personas, :exec_security, :string, default: "full"
    add_column :agent_personas, :exec_host, :string, default: "auto"
    add_column :agent_personas, :exec_timeout, :integer, default: 300
    add_column :agent_personas, :exec_ask, :string, default: "off"
  end
end
