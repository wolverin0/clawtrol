class RenameModelNameToNameInModelLimits < ActiveRecord::Migration[8.1]
  def change
    rename_column :model_limits, :model_name, :name
  end
end
