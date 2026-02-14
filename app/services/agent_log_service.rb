# frozen_string_literal: true

# Retrieves agent transcript/log for a task.
#
# Handles: lazy session_id resolution, fallback to Agent Output in description,
# fallback to output_files summary, transcript file parsing with pagination.
#
# Extracted from Api::V1::TasksController#agent_log to keep the controller thin.
class AgentLogService
  SESSION_ID_FORMAT = /\A[a-zA-Z0-9_\-]+\z/

  Result = Struct.new(:messages, :total_lines, :has_session, :fallback, :error, :task_status, :since, keyword_init: true)

  # @param task [Task] the task to get agent log for
  # @param since [Integer] line offset for pagination (0-based)
  # @param session_resolver [#call] proc that resolves session_key → session_id (optional)
  def initialize(task, since: 0, session_resolver: nil)
    @task = task
    @since = since.to_i
    @session_resolver = session_resolver
  end

  def call
    lazy_resolve_session_id!

    unless @task.agent_session_id.present?
      return fallback_from_description || fallback_from_output_files || no_session_result
    end

    session_id = @task.agent_session_id.to_s
    unless session_id.match?(SESSION_ID_FORMAT)
      return Result.new(messages: [], total_lines: 0, has_session: false, error: "Invalid session ID format", task_status: @task.status)
    end

    transcript_path = TranscriptParser.transcript_path(session_id)
    unless transcript_path
      return fallback_from_description(has_session: true) || transcript_not_found_result
    end

    parsed = TranscriptParser.parse_messages(transcript_path, since: @since)

    Result.new(
      messages: parsed[:messages],
      total_lines: parsed[:total_lines],
      since: @since,
      has_session: true,
      task_status: @task.status
    )
  end

  private

  def lazy_resolve_session_id!
    return if @task.agent_session_id.present?
    return unless @task.agent_session_key.present?
    return unless @session_resolver

    resolved_id = @session_resolver.call(@task.agent_session_key, @task)
    if resolved_id.present?
      @task.update_column(:agent_session_id, resolved_id)
      Rails.logger.info("[AgentLogService] Lazy-resolved session_id=#{resolved_id} for task #{@task.id}")
    end
  end

  def fallback_from_description(has_session: true)
    return nil unless @task.description.present?
    return nil unless @task.description.include?("## Agent Output")

    output_match = @task.description.match(/## Agent Output.*?\n(.*)/m)
    return nil unless output_match

    extracted = output_match[1].strip
    return nil if extracted.blank?

    Result.new(
      messages: [{ role: "assistant", content: [{ type: "text", text: extracted }] }],
      total_lines: 1,
      has_session: has_session,
      fallback: true,
      task_status: @task.status
    )
  end

  def fallback_from_output_files
    return nil unless @task.output_files.present? && @task.output_files.any?

    file_list = @task.output_files.map { |f| "📄 #{f}" }.join("\n")
    Result.new(
      messages: [{ role: "assistant", content: [{ type: "text", text: "Agent produced #{@task.output_files.size} file(s):\n#{file_list}" }] }],
      total_lines: 1,
      has_session: true,
      fallback: true,
      task_status: @task.status
    )
  end

  def no_session_result
    Result.new(messages: [], total_lines: 0, has_session: false, task_status: @task.status)
  end

  def transcript_not_found_result
    Result.new(messages: [], total_lines: 0, has_session: true, error: "Transcript file not found", task_status: @task.status)
  end
end
