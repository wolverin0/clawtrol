# frozen_string_literal: true

module HermesMirror
  class InvalidRequest < StandardError; end

  class Ingestor
    DEFAULT_BOARD_ID = 5
    IDENTIFIER_PATTERN = /\A[A-Za-z0-9._-]+\z/
    TERMINAL_STATES = %w[completed failed cancelled aborted].freeze
    MAX_EVENTS_PER_BATCH = 500
    MAX_BRIEF_LENGTH = 2_000
    MAX_OUTCOME_LENGTH = 50_000

    SessionResult = Data.define(:task, :task_run, :created)
    EventResult = Data.define(:task, :task_run, :created_count, :duplicate_count)
    CompletionResult = Data.define(:task, :task_run, :idempotent)

    def initialize(user)
      @user = user
    end

    def upsert_session(attributes)
      identity = identity_from(attributes)
      brief = required_text(attributes[:brief], "brief", MAX_BRIEF_LENGTH)
      title = optional_text(attributes[:title], 500) || brief.truncate(120)
      task = find_task(identity)
      created = task.nil?

      Task.transaction do
        task ||= create_task(identity, brief, title, attributes[:board_id])
        task.update!(name: title) if task.name != title
        task_run = find_or_create_run(task, identity)
        SessionResult.new(task:, task_run:, created:)
      end
    end

    def append_events(attributes)
      identity = identity_from(attributes)
      events = Array(attributes[:events])
      validate_event_batch!(events)
      task, task_run = find_session!(identity)
      created_count, duplicate_count = persist_events(task, task_run, events)

      EventResult.new(task:, task_run:, created_count:, duplicate_count:)
    end

    def complete_session(attributes)
      identity = identity_from(attributes)
      terminal_state = attributes[:terminal_state].to_s
      validate_terminal_state!(terminal_state)
      outcome = optional_text(attributes[:outcome], MAX_OUTCOME_LENGTH)
      task, task_run = find_session!(identity)
      idempotent = completion_replay?(task_run, terminal_state, outcome)

      persist_completion(task, task_run, terminal_state, outcome, attributes[:ended_at]) unless idempotent
      CompletionResult.new(task:, task_run:, idempotent:)
    end

    private

    attr_reader :user

    def identity_from(attributes)
      profile = valid_identifier(attributes[:profile], "profile", 64)
      session_id = valid_identifier(attributes[:session_id], "session_id", 120)
      { profile:, session_id:, origin_key: "hermes:#{profile}:#{session_id}" }
    end

    def valid_identifier(value, field, maximum)
      identifier = value.to_s
      valid = identifier.present? && identifier.length <= maximum &&
        identifier.match?(IDENTIFIER_PATTERN)
      raise InvalidRequest, "#{field} is invalid" unless valid

      identifier
    end

    def required_text(value, field, maximum)
      text = value.to_s.strip
      raise InvalidRequest, "#{field} is required" if text.blank?
      raise InvalidRequest, "#{field} is too long" if text.length > maximum

      text
    end

    def optional_text(value, maximum)
      return if value.nil?

      text = value.to_s
      raise InvalidRequest, "text is too long" if text.length > maximum

      text
    end

    def find_task(identity)
      user.tasks.find_by(origin_session_key: identity[:origin_key])
    end

    def create_task(identity, brief, title, board_id)
      board = resolve_board(board_id)
      user.tasks.create!(
        board:,
        name: title,
        description: brief,
        origin_session_id: identity[:session_id],
        origin_session_key: identity[:origin_key],
        status: :inbox,
        assigned_to_agent: false
      )
    end

    def resolve_board(board_id)
      board = user.boards.find_by(id: board_id.presence || DEFAULT_BOARD_ID)
      raise InvalidRequest, "Board #{board_id.presence || DEFAULT_BOARD_ID} is unavailable" unless board
      raise InvalidRequest, "The ALL aggregator cannot receive mirrored work" if all_aggregator?(board)

      board
    end

    def all_aggregator?(board)
      board.aggregator? || board.name.to_s.casecmp("ALL").zero?
    end

    def find_or_create_run(task, identity)
      external_key = external_run_key(identity)
      existing = TaskRun.find_by(external_source_key: external_key)
      return existing if existing

      task.task_runs.create!(
        external_source_key: external_key,
        run_id: SecureRandom.uuid,
        run_number: (task.task_runs.maximum(:run_number) || 0) + 1,
        recommended_action: "in_review",
        raw_payload: mirror_metadata(identity)
      )
    end

    def external_run_key(identity)
      "hermes:user-#{user.id}:#{identity[:profile]}:#{identity[:session_id]}"
    end

    def mirror_metadata(identity)
      {
        "source" => "hermes_mirror",
        "profile" => identity[:profile],
        "session_id" => identity[:session_id]
      }
    end

    def find_session!(identity)
      task = user.tasks.find_by!(origin_session_key: identity[:origin_key])
      task_run = TaskRun.find_by!(external_source_key: external_run_key(identity), task:)
      [task, task_run]
    end

    def validate_event_batch!(events)
      raise InvalidRequest, "events must be a non-empty array" if events.empty?
      raise InvalidRequest, "events batch exceeds #{MAX_EVENTS_PER_BATCH}" if events.length > MAX_EVENTS_PER_BATCH
      raise InvalidRequest, "each event must be an object" unless events.all? { |event| event.respond_to?(:to_h) }
    end

    def persist_events(task, task_run, events)
      counts = { created: 0, duplicate: 0 }
      events.each do |event|
        event_attributes = normalize_event(event.to_h, task, task_run)
        persist_event(event_attributes, counts)
      end
      [counts[:created], counts[:duplicate]]
    end

    def persist_event(attributes, counts)
      if AgentActivityEvent.exists?(run_id: attributes[:run_id], seq: attributes[:seq])
        counts[:duplicate] += 1
      else
        AgentActivityEvent.create!(attributes)
        counts[:created] += 1
      end
    rescue ActiveRecord::RecordNotUnique
      counts[:duplicate] += 1
    end

    def normalize_event(event, task, task_run)
      event = event.with_indifferent_access
      {
        task:,
        run_id: task_run.run_id.to_s,
        source: "hermes_mirror",
        level: event[:level].presence || "info",
        event_type: event[:event_type],
        message: event[:message],
        payload: event[:payload].presence || {},
        seq: event[:seq],
        created_at: event_time(event[:timestamp])
      }
    end

    def event_time(value)
      return Time.current if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidRequest, "event timestamp is invalid"
    end

    def validate_terminal_state!(terminal_state)
      return if TERMINAL_STATES.include?(terminal_state)

      raise InvalidRequest, "terminal_state must be one of: #{TERMINAL_STATES.join(', ')}"
    end

    def completion_replay?(task_run, terminal_state, outcome)
      task_run.ended_at.present? &&
        task_run.raw_payload["mirror_terminal_state"] == terminal_state &&
        task_run.agent_output.to_s == outcome.to_s
    end

    def persist_completion(task, task_run, terminal_state, outcome, ended_at)
      run_updates = {
        ended_at: parse_completion_time(ended_at),
        raw_payload: task_run.raw_payload.merge("mirror_terminal_state" => terminal_state)
      }
      run_updates.merge!(agent_output: outcome, summary: outcome.truncate(500)) if outcome.present?

      Task.transaction do
        task_run.update!(run_updates)
        task.update!(status: :done)
      end
    end

    def parse_completion_time(value)
      return Time.current if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidRequest, "ended_at is invalid"
    end
  end
end
