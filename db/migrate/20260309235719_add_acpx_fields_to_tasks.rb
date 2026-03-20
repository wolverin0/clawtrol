class AddAcpxFieldsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :session_type, :string, default: 'oneshot'
    add_column :tasks, :acpx_session_id, :string
  end
end
