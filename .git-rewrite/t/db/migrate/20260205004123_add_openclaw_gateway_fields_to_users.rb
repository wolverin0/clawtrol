class AddOpenclawGatewayFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :openclaw_gateway_url, :string
    add_column :users, :openclaw_gateway_token, :string
  end
end
