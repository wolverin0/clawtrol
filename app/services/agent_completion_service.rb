# frozen_string_literal: true

# AgentCompletionService handles the full lifecycle of marking a task as
# completed by an agent. Extracted from Api::V1::TasksController#agent_complete
# to keep the controller thin.
#
# Responsibilities:
#   - Session ID resolution (from key, or transcript scan)
#   - Output text extraction (from multiple param aliases)
#   - Output files extraction (from multiple param aliases)
#   - TaskRun agent_output storage (P0: no longer writes to description)
#   - Token usage recording
#   - WebSocket broadcast
#   - Validation triggering
#
# Usage:
#   result = AgentCompletionService.new(task, params).call
#   if result.success?
#     render json: result.task_data
#   else
#     render json: { error: result.error }, status: :unprocessable_entity
#   end
#
class AgentCompletionService
  # Accepted param names for output text
  OUTPUT_TEXT_PARAMS = %i[output description summary result text message content].freeze

  # Accepted param names for output files
  OUTPUT_FILES_PARAMS = %i[output_files files created_files changed_files modified_files].freeze

  Result = Struct.new(:task, :success, :error, keyword_init: true) do
    def success?
      success
    end
  end

  # @param task [Task] the task being completed
  # @param params [Hash] controller params
  # @param session_resolver [Proc] optional proc(session_key, task) → session_id
  # @param transcript_scanner [Proc] optional proc(task_id) → session_id
  def initialize(task, params, session_resolver: nil, transcript_scanner: nil)
    @task = task
    @params = params
    @session_resolver = session_resolver
    @transcript_scanner = transcript_scanner
  end

  def call
    link_session!
    output_text = extract_output_text
    raw_files = extract_output_files

    log_completion_info(output_text, raw_files)
    warn_if_empty(output_text, raw_files)

    updates = build_updates(output_text, raw_files)
    @task.update!(updates)

    record_token_usage!
    broadcast_completion!(output_text)
    trigger_validation!

    Result.new(task: @task, success: true)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(task: @task, success: false, error: e.message)
  rescue ArgumentError => e
    # Rails enum raises ArgumentError for invalid status values
    Result.new(task: @task, success: false, error: e.message)
  end

  private

  def link_session!
    sid = @params[:session_id] || @params[:agent_session_id]
    skey = @params[:session_key] || @params[:agent_session_key]

    # Resolve session_id from key if needed
    if skey.present? && sid.blank? && @session_resolver
      sid = @session_resolver.call(skey, @task)
    end

    @task.agent_session_id = sid if sid.present? && @task.agent_session_id.blank?
    @task.agent_session_key = skey if skey.present? && @task.agent_session_key.blank?

    # Last resort: scan transcript files
    if @task.agent_session_id.blank? && @transcript_scanner
      scanned_id = @transcript_scanner.call(@task.id)
      if scanned_id.present?
        @task.agent_session_id = scanned_id
        Rails.logger.info("[AgentCompletionService] Auto-resolved session_id=#{scanned_id} for task #{@task.id}")
      end
    end
  end

  def extract_output_text
    contract = SubAgentOutputContract.from_params(@params)
    return contract.to_markdown if contract

    OUTPUT_TEXT_PARAMS.each do |key|
      value = @params[key]
      return value if value.present?
    end
    nil
  end

  def extract_output_files
    OUTPUT_FILES_PARAMS.each do |key|
      value = @params[key]
      return Array(value).map(&:to_s).reject(&:blank?) if value.present?
    end
    []
  end

  def log_completion_info(output_text, raw_files)
    Rails.logger.info(
      "AgentCompletionService for task #{@task.id}: " \
      "output=#{output_text.present?} (#{output_text&.length || 0} chars), " \
      "files=#{raw_files.size}"
    )
  end

  def warn_if_empty(output_text, raw_files)
    return if output_text.present? || raw_files.any?

    Rails.logger.warn(
      "AgentCompletionService called with no output for task #{@task.id}"
    )
  end

  def build_updates(output_text, raw_files)
    updates = { status: @params[:status].presence || :in_review }

    # P0 Data Contract: store agent output in TaskRun, NOT description
    store_agent_output_in_task_run(output_text) if output_text.present?

    if raw_files.any?
      updates[:output_files] = ((@task.output_files || []) + raw_files).uniq
    end

    updates[:completed_at] = Time.current unless @task.completed_at.present?
    updates[:agent_claimed_at] = nil

    updates
  end

  def store_agent_output_in_task_run(output_text)
    run_id = @params[:run_id].presence ||
             @task.agent_session_id.presence ||
             SecureRandom.uuid

    task_run = @task.task_runs.find_by(run_id: run_id) ||
               @task.task_runs.order(created_at: :desc).first

    if task_run
      run_updates = {}
      run_updates[:agent_output] = output_text if task_run.agent_output.blank?
      run_updates[:prompt_used] = @task.effective_prompt if task_run.prompt_used.blank?
      task_run.update_columns(run_updates) if run_updates.any?
    else
      @task.task_runs.create!(
        run_id: run_id,
        agent_output: output_text,
        prompt_used: @task.effective_prompt,
        status: "completed"
      )
    end

    # Preserve original description if not already saved
    if @task.original_description.blank? && @task.description.present?
      @task.update_column(:original_description, @task.description)
    end
  rescue StandardError => e
    Rails.logger.error("[AgentCompletionService] Failed to store in TaskRun: #{e.message}")
  end

  def record_token_usage!
    return unless defined?(TokenUsage)

    input_tokens = @params[:input_tokens] || @params[:prompt_tokens]
    output_tokens = @params[:output_tokens] || @params[:completion_tokens]
    return unless input_tokens.present? || output_tokens.present?

    TokenUsage.create(
      task: @task,
      model: @params[:model],
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      cache_read_tokens: @params[:cache_read_tokens].to_i,
      cache_write_tokens: @params[:cache_write_tokens].to_i,
      session_key: @task.agent_session_key,
      agent_persona: @task.agent_persona
    )
  rescue StandardError => e
    Rails.logger.warn("[AgentCompletionService] Failed to record token usage: #{e.message}")
  end

  def broadcast_completion!(output_text)
    return unless defined?(AgentActivityChannel)

    AgentActivityChannel.broadcast_status(@task.id, "in_review", {
      output_present: output_text.present?,
      files_count: (@task.output_files || []).size
    })
  rescue StandardError => e
    Rails.logger.warn("[AgentCompletionService] Failed to broadcast: #{e.message}")
  end

  def trigger_validation!
    if @task.validation_command.present?
      ValidationRunnerService.new(@task).call
    elsif defined?(AutoValidationJob)
      AutoValidationJob.perform_later(@task.id)
    end
  rescue StandardError => e
    Rails.logger.warn("[AgentCompletionService] Failed to trigger validation: #{e.message}")
  end
end
