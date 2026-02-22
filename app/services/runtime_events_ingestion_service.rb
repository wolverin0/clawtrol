# frozen_string_literal: true

class RuntimeEventsIngestionService
  Result = Struct.new(:created, :duplicates, :errors, keyword_init: true)

  DEFAULT_SOURCE = "runtime_hook"

  def self.call(task:, events:, run_id:, map_id: nil, source: DEFAULT_SOURCE)
    new(task: task, events: events, run_id: run_id, map_id: map_id, source: source).call
  end

  def initialize(task:, events:, run_id:, map_id:, source:)
    @task = task
    @events = Array(events).compact
    @run_id = run_id.to_s
    @map_id = map_id.to_s
    @source = source.to_s.presence || DEFAULT_SOURCE
    @seq_cursor = nil
  end

  def call
    created = 0
    duplicates = 0
    errors = []
    runtime_broadcasts = []

    @events.each_with_index do |event, index|
      normalized = normalize_event(event, index)

      AgentActivityEvent.create!(normalized[:attrs])
      created += 1
      runtime_broadcasts << normalized[:broadcast]
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      duplicates += 1
    rescue StandardError => e
      errors << e.message
    end

    AgentActivityChannel.broadcast_runtime_events(@task.id, runtime_broadcasts) if runtime_broadcasts.any?

    Result.new(created: created, duplicates: duplicates, errors: errors)
  end

  private

  def normalize_event(event, index)
    raw_hash = if event.respond_to?(:to_unsafe_h)
      event.to_unsafe_h
    else
      event.to_h
    end

    h = raw_hash.with_indifferent_access
    raw_type = h[:event_type] || h[:type] || h[:event] || h[:name]
    event_type = normalize_event_type(raw_type)

    run_id = h[:run_id].presence || @run_id
    seq = extract_seq(h) || next_sequence
    created_at = parse_time(h[:created_at] || h[:timestamp]) || Time.current
    level = normalize_level(h[:level], event_type)
    payload = normalize_payload(h, event_type)
    message = normalize_message(h, event_type, payload)

    attrs = {
      task_id: @task.id,
      run_id: run_id,
      source: h[:source].presence || @source,
      level: level,
      event_type: event_type,
      message: message,
      payload: payload,
      seq: seq,
      created_at: created_at
    }

    broadcast = {
      event_type: event_type,
      message: message,
      level: level,
      source: attrs[:source],
      seq: seq,
      created_at: created_at.iso8601,
      payload: payload
    }

    status = h[:status].presence
    status ||= message if event_type == "status" && message.present?
    broadcast[:status] = status if status.present?

    { attrs: attrs, broadcast: broadcast }
  end

  def normalize_event_type(raw)
    type = raw.to_s
    down = type.downcase
    return type if AgentActivityEvent::EVENT_TYPES.include?(type)

    if AgentActivityEvent::EVENT_TYPES.include?(type.tr("-", "_"))
      return type.tr("-", "_")
    end

    return "tool_call" if down.include?("tool_call") || down.include?("toolcall") || down.include?("tool call")
    return "tool_result" if down.include?("tool_result") || down.include?("toolresult") || down.include?("tool result")
    return "final_summary" if down.include?("final_summary") || down.include?("final summary") || down.include?("summary")
    return "status" if down.include?("status") || down.include?("state")
    return "error" if down.include?("error") || down.include?("exception") || down.include?("failed")
    return "heartbeat" if down.include?("heartbeat") || down.include?("pulse")

    "message"
  end

  def normalize_level(raw, event_type)
    level = raw.to_s
    return level if AgentActivityEvent::LEVELS.include?(level)
    return "error" if event_type == "error"

    "info"
  end

  def normalize_payload(h, event_type)
    payload = h[:payload] || h[:data] || {}
    payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
    payload = {} unless payload.is_a?(Hash)

    payload = payload.deep_stringify_keys

    if event_type == "tool_call"
      tool_name = h[:tool_name] || h[:tool] || h[:name] || payload["tool_name"] || payload["name"]
      input = extract_tool_input(h, payload)
      payload["tool_name"] = tool_name if tool_name.present?
      payload["input"] = input if input.present?
    end

    payload
  end

  def extract_tool_input(h, payload)
    input = h[:input]
    input = payload["input"] if input.blank?
    input = h[:args] if input.blank?
    input = input.to_unsafe_h if input.respond_to?(:to_unsafe_h)
    input = {} unless input.is_a?(Hash)

    {
      "command" => input["command"] || input[:command] || h[:command] || h[:cmd] || payload["command"],
      "cwd" => input["cwd"] || input[:cwd] || input["workdir"] || input[:workdir] || h[:cwd] || h[:workdir],
      "path" => input["path"] || input[:path] || input["file_path"] || input[:file_path] || input["file"] || input[:file] || h[:path]
    }.compact
  end

  def normalize_message(h, event_type, payload)
    message = h[:message] || h[:text] || h[:detail] || h[:summary] || h[:status] || h[:result]

    if message.blank? && event_type == "tool_call"
      message = payload.dig("input", "command") || payload["tool_name"]
    end

    message.to_s.slice(0, 5000)
  end

  def extract_seq(h)
    seq = h[:seq] || h[:sequence] || h[:event_sequence]
    return seq.to_i if seq.present? && seq.to_i.positive?

    nil
  end

  def next_sequence
    @seq_cursor ||= AgentActivityEvent.where(task_id: @task.id, run_id: @run_id).maximum(:seq).to_i
    @seq_cursor += 1
  end

  def parse_time(raw)
    return nil if raw.blank?

    Time.iso8601(raw.to_s)
  rescue StandardError
    nil
  end
end
