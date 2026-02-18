class AllowNullFactoryLoopOnCycleLogs < ActiveRecord::Migration[8.1]
  def change
    change_column_null :factory_cycle_logs, :factory_loop_id, true
  end
end
