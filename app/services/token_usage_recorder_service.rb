# frozen_string_literal: true

# Records token usage for a task from agent params or transcript extraction.
#
# Extracted from Api::V1::TasksController to centralize token accounting
# logic and enable reuse from hooks, background jobs, etc.
#
# Usage:
#   TokenUsageRecorderService.record(task, input_tokens: 100, output_tokens: 200, model: "opus")
#   TokenUsageRecorderService.record(task)  # auto-extracts from transcript
#
class TokenUsageRecorderService
  # Record token usage for a task.
  #
  # If explicit token counts are provided and non-zero, uses those.
  # Otherwise, attempts to extract from the task's session transcript.
  #
  # @param task [Task] the task to record usage for
  # @param input_tokens [Integer] explicit input token count (default: 0)
  # @param output_tokens [Integer] explicit output token count (default: 0)
  # @param model [String, nil] the model name (falls back to task.model)
  # @return [TokenUsage, nil] the created record, or nil if no data
  def self.record(task, input_tokens: 0, output_tokens: 0, model: nil)
    model ||= task.model

    # If tokens not provided directly, try to extract from session transcript
    if input_tokens == 0 && output_tokens == 0
      session_tokens = extract_from_session(task)
      if session_tokens
        input_tokens = session_tokens[:input_tokens]
        output_tokens = session_tokens[:output_tokens]
        model ||= session_tokens[:model]
      end
    end

    # Only record if we have meaningful data
    return nil if input_tokens == 0 && output_tokens == 0

    TokenUsage.record_from_session(
      task: task,
      session_data: {
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        model: model
      },
      session_key: task.agent_session_key
    )
  rescue StandardError => e
    Rails.logger.error("[TokenUsageRecorder] Failed to record for task #{task.id}: #{e.message}")
    nil
  end

  # Extract token counts from an OpenClaw session transcript.
  #
  # @param task [Task] the task whose session transcript to parse
  # @return [Hash, nil] { input_tokens:, output_tokens:, model: } or nil
  def self.extract_from_session(task)
    return nil unless task.agent_session_id.present?

    transcript_file = TranscriptParser.transcript_path(task.agent_session_id)
    return nil unless transcript_file

    input_tokens = 0
    output_tokens = 0
    model = nil

    TranscriptParser.each_entry(transcript_file) do |entry, _line_num|
      if entry["usage"].is_a?(Hash)
        input_tokens += entry["usage"]["input_tokens"].to_i
        output_tokens += entry["usage"]["output_tokens"].to_i
      end
      model ||= entry["model"] if entry["model"].present?
    end

    return nil if input_tokens == 0 && output_tokens == 0

    { input_tokens: input_tokens, output_tokens: output_tokens, model: model }
  rescue StandardError => e
    Rails.logger.error("[TokenUsageRecorder] Failed to extract from session: #{e.message}")
    nil
  end
end
