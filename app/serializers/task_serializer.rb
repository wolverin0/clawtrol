# frozen_string_literal: true

# Centralized JSON serialization for Task objects.
# Used by API controllers and Telegram Mini App for consistent representation.
#
# Usage:
#   TaskSerializer.new(task).as_json           # full representation
#   TaskSerializer.new(task, mini: true).as_json  # compact representation
#   TaskSerializer.collection(tasks)           # serialize array
#   TaskSerializer.collection(tasks, mini: true)
class TaskSerializer
  FULL_ATTRIBUTES = %i[
    id name description status priority position
    board_id user_id agent_persona_id parent_task_id followup_task_id
    tags output_files
    blocked completed nightly recurring assigned_to_agent
    model pipeline_stage execution_plan compiled_prompt routed_model
    agent_session_id agent_session_key agent_claimed_at
    context_usage_percent
    error_message error_at retry_count
    validation_command validation_status validation_output
    review_type review_status review_config review_result
    recurrence_rule recurrence_time nightly_delay_hours
    due_date completed_at assigned_at
    suggested_followup
    origin_chat_id origin_thread_id
    created_at updated_at
  ].freeze

  MINI_ATTRIBUTES = %i[
    id name status tags priority board_id
    created_at updated_at completed assigned_to_agent
  ].freeze

  attr_reader :task, :options

  def initialize(task, **options)
    @task = task
    @options = options
  end

  def as_json(_opts = nil)
    attrs = mini? ? MINI_ATTRIBUTES : FULL_ATTRIBUTES
    result = {}

    attrs.each do |attr|
      value = task.try(attr)
      # Format timestamps as ISO8601
      result[attr] = value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) ? value.iso8601(3) : value
    end

    unless mini?
      # Include associations
      if task.association(:agent_persona).loaded? || task.agent_persona_id.present?
        persona = task.agent_persona
        if persona
          result[:agent_persona] = { id: persona.id, name: persona.name, emoji: persona.try(:emoji) }
        end
      end

      # Dependencies
      if task.association(:task_dependencies).loaded?
        result[:dependency_ids] = task.dependencies.map(&:id)
      end
      if task.association(:inverse_dependencies).loaded?
        result[:dependent_ids] = task.dependents.map(&:id)
      end

      # Computed fields
      result[:openclaw_spawn_model] = task.try(:openclaw_spawn_model)
      result[:pipeline_active] = task.try(:pipeline_active?)
    end

    result
  end

  def mini?
    options[:mini] == true
  end

  # Serialize a collection of tasks.
  #
  # @param tasks [Array<Task>, ActiveRecord::Relation]
  # @param options [Hash] passed to each serializer instance
  # @return [Array<Hash>]
  def self.collection(tasks, **options)
    tasks.map { |task| new(task, **options).as_json }
  end
end
