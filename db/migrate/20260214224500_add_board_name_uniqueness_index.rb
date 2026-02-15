# frozen_string_literal: true

class AddBoardNameUniquenessIndex < ActiveRecord::Migration[8.0]
  def change
    unless index_exists?(:boards, [:user_id, :name], name: "index_boards_on_user_id_and_name")
      add_index :boards, [:user_id, :name], unique: true, name: "index_boards_on_user_id_and_name"
    end
  end
end
