# frozen_string_literal: true

class AgentActivityIngestionService
  Result = Struct.new(:created, :duplicates, :errors, keyword_init: true)

  def self.call(task:, events:)
    new(task: task, events: events).call
  end

  def initialize(task:, events:)
    @task = task
    @events = Array(events)
  end

  def call
    created = 0
    duplicates = 0
    errors = []

    @events.each do |event|
      attrs = normalize_event(event)
      AgentActivityEvent.create!(attrs)
      created += 1
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      duplicates += 1
    rescue StandardError => e
      errors << e.message
    end

    Result.new(created: created, duplicates: duplicates, errors: errors)
  end

  private

  def normalize_event(event)
    raw_hash = if event.respond_to?(:to_unsafe_h)
      event.to_unsafe_h
    else
      event.to_h
    end

    h = raw_hash.with_indifferent_access
    {
      task_id: @task.id,
      run_id: h[:run_id].to_s,
      source: h[:source].presence || "orchestrator",
      level: h[:level].presence || "info",
      event_type: normalize_event_type(h[:event_type]),
      message: h[:message].to_s,
      payload: (h[:payload].is_a?(Hash) ? h[:payload] : {}),
      seq: h[:seq].to_i,
      created_at: parse_time(h[:created_at]) || Time.current
    }
  end

  def normalize_event_type(type)
    t = type.to_s
    return t if AgentActivityEvent::EVENT_TYPES.include?(t)
    "message"
  end

  def parse_time(raw)
    return nil if raw.blank?
    Time.iso8601(raw.to_s)
  rescue StandardError
    nil
  end
end
