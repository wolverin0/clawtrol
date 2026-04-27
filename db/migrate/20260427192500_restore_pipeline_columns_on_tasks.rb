# frozen_string_literal: true

# Restores pipeline_* columns on the `tasks` table that were silently
# dropped from the production database despite migrations
# 20260214170000, 20260214200819, and 20260218120000 being recorded
# as applied in `schema_migrations`. The columns are referenced
# throughout the codebase (HooksController, PipelineProcessorJob,
# TaskAgentLifecycle, ClawRouterService, etc.) and any code path that
# touches them currently raises NoMethodError in production.
#
# This migration is idempotent — `column_exists?` / `index_exists?`
# guards make it safe to run on databases where the columns survived.
class RestorePipelineColumnsOnTasks < ActiveRecord::Migration[8.1]
  class MigrationTask < ActiveRecord::Base
    self.table_name = "tasks"
  end

  def up
    add_column :tasks, :pipeline_stage, :string unless column_exists?(:tasks, :pipeline_stage)
    add_column :tasks, :pipeline_type, :string unless column_exists?(:tasks, :pipeline_type)
    add_column :tasks, :pipeline_enabled, :boolean, default: false, null: false unless column_exists?(:tasks, :pipeline_enabled)
    add_column :tasks, :pipeline_log, :jsonb unless column_exists?(:tasks, :pipeline_log)

    add_index :tasks, :pipeline_stage unless index_exists?(:tasks, :pipeline_stage)
    add_index :tasks, :pipeline_enabled unless index_exists?(:tasks, :pipeline_enabled)

    repair_pipeline_stage_alignment!
  end

  def down
    remove_index :tasks, :pipeline_enabled if index_exists?(:tasks, :pipeline_enabled)
    remove_index :tasks, :pipeline_stage if index_exists?(:tasks, :pipeline_stage)
    remove_column :tasks, :pipeline_log if column_exists?(:tasks, :pipeline_log)
    remove_column :tasks, :pipeline_enabled if column_exists?(:tasks, :pipeline_enabled)
    remove_column :tasks, :pipeline_type if column_exists?(:tasks, :pipeline_type)
    remove_column :tasks, :pipeline_stage if column_exists?(:tasks, :pipeline_stage)
  end

  private

  # Mirrors the backfill logic from migration 20260218120000. Re-running
  # is safe because each query is scoped by status + a guard on the
  # current pipeline_stage value.
  def repair_pipeline_stage_alignment!
    return unless column_exists?(:tasks, :pipeline_stage)

    now = Time.current
    in_progress = 2
    in_review = 3
    done = 4
    archived = 5
    inbox = 0
    up_next = 1

    non_terminal = [nil, "", "unstarted", "triaged", "context_ready", "routed", "executing", "verifying"]

    MigrationTask.where(status: in_progress).where.not(pipeline_stage: "executing").update_all(pipeline_stage: "executing", updated_at: now)
    MigrationTask.where(status: in_review).where.not(pipeline_stage: "verifying").update_all(pipeline_stage: "verifying", updated_at: now)
    MigrationTask.where(status: done).where.not(pipeline_stage: "completed").update_all(pipeline_stage: "completed", updated_at: now)
    MigrationTask.where(status: archived).where(pipeline_stage: non_terminal).update_all(pipeline_stage: "completed", updated_at: now)
    MigrationTask.where(status: [inbox, up_next]).where(pipeline_stage: non_terminal - ["unstarted"]).update_all(pipeline_stage: "unstarted", updated_at: now)
  end
end
