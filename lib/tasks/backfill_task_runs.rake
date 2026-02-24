# frozen_string_literal: true

namespace :clawdeck do
  desc "Backfill task_runs with agent_output/agent_activity_md/follow_up_prompt extracted from task description"
  task backfill_task_run_output: :environment do
    migrated = 0
    skipped = 0
    no_run = 0

    Task.where("description LIKE ?", "%## Agent Output%").find_each do |task|
      desc = task.description.to_s

      # Extract Agent Output section
      agent_output = nil
      if (match = desc.match(/(?:^|\n)##\s*Agent Output\s*\n(.*?)(?:\n##\s|\n\n---\n\n|\z)/m))
        agent_output = match[1].to_s.strip
      end

      # Extract Agent Activity section
      agent_activity_md = nil
      if (match = desc.match(/(?:^|\n)##\s*Agent Activity\s*\n(.*?)(?:\n##\s|\z)/m))
        agent_activity_md = match[1].to_s.strip
      end

      # Extract Follow-up Prompt section
      follow_up_prompt = nil
      if (match = desc.match(/(?:^|\n)##\s*Follow-up Prompt[^\n]*\n(.*?)(?:\n##\s|\z)/m))
        follow_up_prompt = match[1].to_s.strip
      end

      # Find latest TaskRun for this task
      task_run = task.task_runs.order(created_at: :desc).first
      unless task_run
        no_run += 1
        next
      end

      # Skip if already populated
      if task_run.agent_output.present?
        skipped += 1
        next
      end

      updates = {}
      updates[:agent_output] = agent_output if agent_output.present?
      updates[:agent_activity_md] = agent_activity_md if agent_activity_md.present?
      updates[:follow_up_prompt] = follow_up_prompt if follow_up_prompt.present?

      # Snapshot prompt_used from compiled_prompt or effective prompt chain
      if task_run.prompt_used.blank?
        updates[:prompt_used] = task.compiled_prompt.presence ||
          task.execution_prompt.presence ||
          task.original_description.presence
      end

      if updates.any?
        task_run.update_columns(updates)
        migrated += 1
      else
        skipped += 1
      end
    end

    puts "Backfill complete: migrated=#{migrated} skipped=#{skipped} no_run=#{no_run}"
  end
end
