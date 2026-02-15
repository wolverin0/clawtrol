# frozen_string_literal: true

# Encapsulates the business logic for creating a follow-up task.
# Consolidates parent completion + child configuration into a single transaction
# instead of multiple sequential update! calls.
#
# Usage:
#   result = TaskFollowupService.new(parent_task).call(
#     name: "Follow up: fix tests",
#     description: "...",
#     model: "codex",
#     destination: "up_next",
#     continue_session: true,
#     inherit_session_key: "abc123"
#   )
#   result.followup  # => Task
#   result.success?  # => true
#
class TaskFollowupService
  Result = Struct.new(:followup, :success, :error, keyword_init: true) do
    def success? = success
  end

  def initialize(parent_task)
    @parent = parent_task
  end

  # @param name [String] follow-up task name (defaults to "Follow up: <parent>")
  # @param description [String, nil]
  # @param model [String, nil] override model (nil = inherit from parent)
  # @param destination [String] one of "inbox", "up_next", "in_progress", "nightly"
  # @param continue_session [Boolean] whether to carry over the parent's session key
  # @param inherit_session_key [String, nil] the session key to carry over
  # @return [Result]
  def call(name: nil, description: nil, model: nil, destination: "inbox",
           continue_session: false, inherit_session_key: nil)
    followup = nil

    ActiveRecord::Base.transaction do
      # 1. Create the follow-up task (inherits board, tags, etc. from parent)
      followup = @parent.create_followup_task!(
        followup_name: name.presence || "Follow up: #{@parent.name}",
        followup_description: description
      )

      # 2. Auto-complete the parent
      @parent.update!(status: "done", completed: true, completed_at: Time.current)

      # 3. Build a single attribute hash for the follow-up instead of N update! calls
      attrs = {}
      attrs[:model] = model if model.present?

      if continue_session && inherit_session_key.present?
        attrs[:agent_session_key] = inherit_session_key
      end

      case destination
      when "up_next"
        attrs.merge!(status: :up_next, assigned_to_agent: true, assigned_at: Time.current)
      when "in_progress"
        attrs.merge!(status: :in_progress, assigned_to_agent: true, assigned_at: Time.current)
      when "nightly"
        attrs.merge!(status: :up_next, nightly: true, assigned_to_agent: true, assigned_at: Time.current)
      end

      followup.update!(attrs) if attrs.any?
    end

    Result.new(followup: followup, success: true)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    Result.new(followup: nil, success: false, error: e.message)
  end
end
