class CreateZeroclawAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :zeroclaw_agents do |t|
      t.string :name
      t.string :url
      t.string :mode
      t.string :status
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :zeroclaw_agents, :status
  end
end
