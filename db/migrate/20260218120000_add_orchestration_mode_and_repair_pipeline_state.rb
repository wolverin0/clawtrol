# frozen_string_literal: true

class AddOrchestrationModeAndRepairPipelineState < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = 'users'
  end

  class MigrationTask < ActiveRecord::Base
    self.table_name = 'tasks'
  end

  def up
    add_column :users, :orchestration_mode, :string, default: 'openclaw_only', null: false unless column_exists?(:users, :orchestration_mode)

    if column_exists?(:tasks, :pipeline_enabled)
      change_column_default :tasks, :pipeline_enabled, from: true, to: false
    end

    MigrationUser.where(orchestration_mode: [nil, '']).update_all(orchestration_mode: 'openclaw_only')

    repair_pipeline_stage_alignment!
  end

  def down
    change_column_default :tasks, :pipeline_enabled, from: false, to: true if column_exists?(:tasks, :pipeline_enabled)
    remove_column :users, :orchestration_mode if column_exists?(:users, :orchestration_mode)
  end

  private

  def repair_pipeline_stage_alignment!
    now = Time.current

    inbox = 0
    up_next = 1
    in_progress = 2
    in_review = 3
    done = 4
    archived = 5

    non_terminal = [nil, '', 'unstarted', 'triaged', 'context_ready', 'routed', 'executing', 'verifying']

    MigrationTask.where(status: in_progress).where.not(pipeline_stage: 'executing').update_all(pipeline_stage: 'executing', updated_at: now)
    MigrationTask.where(status: in_review).where.not(pipeline_stage: 'verifying').update_all(pipeline_stage: 'verifying', updated_at: now)
    MigrationTask.where(status: done).where.not(pipeline_stage: 'completed').update_all(pipeline_stage: 'completed', updated_at: now)
    MigrationTask.where(status: archived).where(pipeline_stage: non_terminal).update_all(pipeline_stage: 'completed', updated_at: now)
    MigrationTask.where(status: [inbox, up_next]).where(pipeline_stage: non_terminal - ['unstarted']).update_all(pipeline_stage: 'unstarted', updated_at: now)
  end
end
