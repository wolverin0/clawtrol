# frozen_string_literal: true

class AddBudgetCapsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :daily_budget_usd, :decimal, precision: 10, scale: 2, if_not_exists: true
    add_column :users, :monthly_budget_usd, :decimal, precision: 10, scale: 2, if_not_exists: true
  end
end
