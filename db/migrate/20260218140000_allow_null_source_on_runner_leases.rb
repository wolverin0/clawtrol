class AllowNullSourceOnRunnerLeases < ActiveRecord::Migration[8.1]
  def change
    change_column_null :runner_leases, :source, true
  end
end
