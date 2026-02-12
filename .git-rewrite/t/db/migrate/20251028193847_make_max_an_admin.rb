class MakeMaxAnAdmin < ActiveRecord::Migration[8.1]
  def up
    User.find_by(email_address: "max@mx.works")&.update(admin: true)
  end

  def down
    User.find_by(email_address: "max@mx.works")&.update(admin: false)
  end
end
