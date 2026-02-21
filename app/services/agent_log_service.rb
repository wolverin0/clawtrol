# frozen_string_literal: true

# Retrieves task-scoped agent transcript/log for a task.
#
# Strict behavior:
# - Never fallback to task description/output files.
# - Never fallback to unrelated sessions.
# - If no valid mapped session/transcript exists, return empty with has_session=false.
class AgentLogService
  SESSION_ID_FORMAT = /\A[a-zA-Z0-9_\-]+\z/
  TASK_MARKER_LINES = 20

  Result = Struct.new(:messages, :total_lines, :has_session, :fallback, :error, :task_status, :since, :persisted_count, keyword_init: true)

  def initialize(task, since: 0, session_resolver: nil)
    @task = task
    @since = since.to_i
    @session_resolver = session_resolver
  end

  def call
    lazy_resolve_session_id!
    return no_session_result unless @task.agent_session_id.present?

    session_id = @task.agent_session_id.to_s
    return no_session_result unless session_id.match?(SESSION_ID_FORMAT)

    transcript_path = TranscriptParser.transcript_path(session_id)
    return no_session_result unless transcript_path
    return no_session_result unless transcript_matches_task_scope?(transcript_path)

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

  def transcript_matches_task_scope?(transcript_path)
    sample_lines = []
    File.foreach(transcript_path).with_index do |line, idx|
      break if idx >= TASK_MARKER_LINES
      sample_lines << line
    end

    sample = sample_lines.join
    task_patterns = ["Task ##{@task.id}:", "## Task ##{@task.id}:", "Task ##{@task.id}"]
    has_task_marker = task_patterns.any? { |pattern| sample.include?(pattern) }
    return false unless has_task_marker

    return true if @task.agent_session_key.blank?

    sample.include?(@task.agent_session_key.to_s) || sample.include?("\"session_key\":\"#{@task.agent_session_key}\"")
  rescue StandardError
    false
  end

  def no_session_result
    Result.new(messages: [], total_lines: 0, has_session: false, task_status: @task.status, persisted_count: 0)
  end
end
