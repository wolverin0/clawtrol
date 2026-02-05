# frozen_string_literal: true

class AddAutoClaimToBoards < ActiveRecord::Migration[8.1]
  def change
    add_column :boards, :auto_claim_enabled, :boolean, default: false, null: false
    add_column :boards, :auto_claim_tags, :string, array: true, default: []
    add_column :boards, :auto_claim_prefix, :string
    add_column :boards, :last_auto_claim_at, :datetime

    add_index :boards, :auto_claim_enabled, where: "auto_claim_enabled = true"
  end
end
