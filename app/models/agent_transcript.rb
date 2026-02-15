# frozen_string_literal: true

class AgentTranscript < ApplicationRecord
  belongs_to :task, optional: true, inverse_of: :task
  belongs_to :task_run, optional: true

  validates :session_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[captured parsed failed] }
  validates :total_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :input_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :output_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :message_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tool_call_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :runtime_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :session_id, length: { maximum: 255 }
  validates :session_key, length: { maximum: 255 }, allow_nil: true
  validates :model, length: { maximum: 100 }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_task, ->(task_id) { where(task_id: task_id) }
  scope :with_prompt, -> { where.not(prompt_text: nil) }

  def self.capture_from_jsonl!(path, task: nil, task_run: nil, session_id: nil)
    content = File.read(path, encoding: "UTF-8")
    sid = session_id || File.basename(path, ".jsonl").sub(/\.jsonl\.deleted.*/, "")

    return find_by(session_id: sid) if exists?(session_id: sid)

    prompt = nil
    last_assistant = nil
    tokens_in = 0
    tokens_out = 0
    total_msgs = 0
    tool_calls = 0
    first_ts = nil
    last_ts = nil
    model = nil

    content.each_line do |line|
      next if line.blank?

      begin
        data = JSON.parse(line)
      rescue JSON::ParserError
        next
      end

      ts = data["timestamp"]
      first_ts ||= ts
      last_ts = ts

      if data["type"] == "message"
        msg = data["message"] || data
        role = msg["role"]
        total_msgs += 1

        if role == "user" && prompt.nil?
          c = msg["content"]
          if c.is_a?(Array)
            c = c.select { |x| x["type"] == "text" }.map { |x| x["text"] }.join("\n")
          end
          prompt = c.to_s.first(50_000)
        elsif role == "assistant"
          c = msg["content"]
          if c.is_a?(Array)
            c = c.select { |x| x["type"] == "text" }.map { |x| x["text"] }.join("\n")
          end
          last_assistant = c.to_s.first(50_000)
          model ||= msg["model"] || data["model"]
        end
      end

      if data["type"] == "tool_call" || (data.dig("message", "tool_calls")&.any?)
        tool_calls += 1
      end

      if (usage = data["usage"] || data.dig("message", "usage"))
        tokens_in += (usage["input_tokens"] || usage["prompt_tokens"] || 0).to_i
        tokens_out += (usage["output_tokens"] || usage["completion_tokens"] || 0).to_i
      end
    end

    runtime = nil
    if first_ts && last_ts
      begin
        runtime = (Time.parse(last_ts) - Time.parse(first_ts)).to_i
      rescue StandardError
        nil
      end
    end

    create!(
      task: task,
      task_run: task_run,
      session_id: sid,
      session_key: task&.agent_session_key,
      model: model,
      prompt_text: prompt,
      output_text: last_assistant,
      total_tokens: tokens_in + tokens_out,
      input_tokens: tokens_in,
      output_tokens: tokens_out,
      message_count: total_msgs,
      tool_call_count: tool_calls,
      runtime_seconds: runtime,
      status: "parsed",
      raw_jsonl: (content.bytesize <= 2_000_000 ? content : nil),
      metadata: { source_path: path.to_s, captured_at: Time.current.iso8601 }
    )
  rescue StandardError => e
    create!(
      session_id: sid || SecureRandom.uuid,
      task: task,
      status: "failed",
      metadata: { error: e.message, source_path: path.to_s }
    )
  end
end
