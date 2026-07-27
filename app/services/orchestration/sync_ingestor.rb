# frozen_string_literal: true

module Orchestration
  class InvalidRequest < StandardError; end

  class SyncIngestor
    DEFAULT_BOARD_ID = 5
    IDENTIFIER_PATTERN = /\A[A-Za-z0-9._-]+\z/
    SOURCE_STATES = %w[queued ready running review done blocked failed cancelled].freeze
    BATCH_LIMITS = { tasks: 1_000, events: 500, messages: 200, intent_results: 100 }.freeze
    STATUS_MAP = {
      "queued" => :inbox,
      "ready" => :up_next,
      "running" => :in_progress,
      "review" => :in_review,
      "done" => :done,
      "blocked" => :up_next,
      "failed" => :in_review,
      "cancelled" => :done
    }.freeze

    Result = Data.define(:source, :accepted, :intents)

    def initialize(user)
      @user = user
    end

    def sync(attributes)
      attrs = attributes.with_indifferent_access
      profile = valid_identifier(attrs[:profile], "profile", 64)
      batches = extract_batches(attrs)
      accepted = empty_counts

      source = ApplicationRecord.transaction do
        record = upsert_source(profile, attrs)
        task_map = sync_tasks(record, batches[:tasks], accepted)
        sync_dependencies(record, batches[:tasks], task_map)
        sync_events(record, batches[:events], accepted)
        sync_messages(record, batches[:messages], accepted)
        sync_intent_results(record, batches[:intent_results], accepted)
        record
      end

      Result.new(
        source:,
        accepted:,
        intents: source.orchestration_intents.pending.limit(100).map(&:as_bridge_json)
      )
    end

    private

    attr_reader :user

    def extract_batches(attributes)
      BATCH_LIMITS.to_h do |name, limit|
        values = Array(attributes[name])
        raise InvalidRequest, "#{name} batch exceeds #{limit}" if values.length > limit
        raise InvalidRequest, "#{name} must contain objects" unless values.all? { |item| item.respond_to?(:to_h) }

        [name, values.map { |item| item.to_h.with_indifferent_access }]
      end
    end

    def empty_counts
      {
        tasks: 0,
        events: 0,
        messages: 0,
        intent_results: 0,
        duplicates: 0
      }
    end

    def upsert_source(profile, attributes)
      source = user.orchestration_sources.find_or_initialize_by(profile:)
      health = PayloadSanitizer.call(attributes[:health] || {})
      source_attributes = {
        status: normalize_source_status(health["status"]),
        last_seen_at: Time.current,
        generated_at: parse_time(attributes[:generated_at], allow_blank: true),
        last_error: PayloadSanitizer.text(health["last_error"], maximum: 2_000).presence,
        health:
      }
      source_attributes[:panes] = PayloadSanitizer.call(attributes[:panes]) if attributes.key?(:panes)
      source.update!(source_attributes)
      source
    end

    def sync_tasks(source, snapshots, accepted)
      snapshots.each_with_object({}) do |snapshot, task_map|
        task = upsert_task(source, snapshot)
        task_map[snapshot[:id].to_s] = task
        accepted[:tasks] += 1
      end
    end

    def upsert_task(source, snapshot)
      ledger_id = valid_identifier(snapshot[:id], "task id", 80)
      state = valid_state(snapshot[:state])
      origin_key = task_origin_key(source.profile, ledger_id)
      task = user.tasks.find_or_initialize_by(origin_session_key: origin_key)
      new_record = task.new_record?

      task.assign_attributes(task_attributes(source, snapshot, ledger_id, state, new_record))
      task.description = required_text(snapshot[:brief] || snapshot[:goal], "brief", 2_000) if new_record
      task.save!
      sync_task_run(task, source, snapshot, ledger_id, state)
      task
    end

    def task_attributes(source, snapshot, ledger_id, state, new_record)
      {
        board: new_record ? projection_board : nil,
        name: required_text(snapshot[:title], "title", 500),
        origin_session_id: ledger_id,
        status: STATUS_MAP.fetch(state),
        blocked: state == "blocked",
        assigned_to_agent: false,
        priority: normalize_priority(snapshot[:priority]),
        error_at: state == "failed" ? parse_time(snapshot[:updated_at], allow_blank: true) || Time.current : nil,
        error_message: state == "failed" ? PayloadSanitizer.text(snapshot[:blocker], maximum: 50_000).presence : nil,
        tags: orchestration_tags(snapshot),
        state_data: orchestration_state_data(source, snapshot, ledger_id, state)
      }.compact
    end

    def orchestration_state_data(source, snapshot, ledger_id, state)
      {
        "orchestration" => PayloadSanitizer.call(
          {
            "profile" => source.profile,
            "ledger_id" => ledger_id,
            "source_state" => state,
            "project" => snapshot[:project],
            "kind" => snapshot[:kind],
            "blocker" => snapshot[:blocker],
            "next_action" => snapshot[:next_action],
            "lease" => snapshot[:lease],
            "acceptance" => snapshot[:acceptance],
            "evidence" => snapshot[:evidence],
            "source_updated_at" => snapshot[:updated_at]
          }
        )
      }
    end

    def sync_task_run(task, source, snapshot, ledger_id, state)
      attempt = Integer(snapshot[:attempt].presence || 0)
      return if attempt <= 0

      task_run = find_or_create_run(task, source, ledger_id, attempt)
      task_run.update!(
        summary: PayloadSanitizer.text(snapshot[:summary], maximum: 2_000).presence,
        agent_output: PayloadSanitizer.text(snapshot[:outcome]).presence,
        ended_at: terminal_state?(state) ? parse_time(snapshot[:updated_at], allow_blank: true) || Time.current : nil,
        raw_payload: task_run.raw_payload.merge(
          "source_state" => state,
          "project" => PayloadSanitizer.text(snapshot[:project], maximum: 200)
        )
      )
    rescue ArgumentError
      raise InvalidRequest, "attempt is invalid"
    end

    def find_or_create_run(task, source, ledger_id, attempt)
      external_key = "wezbridge:user-#{user.id}:#{source.profile}:#{ledger_id}:attempt:#{attempt}"
      TaskRun.find_or_create_by!(external_source_key: external_key) do |run|
        run.task = task
        run.run_id = SecureRandom.uuid
        run.run_number = next_run_number(task)
        run.recommended_action = "in_review"
        run.raw_payload = {
          "source" => "wezbridge",
          "profile" => source.profile,
          "ledger_id" => ledger_id,
          "attempt" => attempt
        }
      end
    end

    def sync_dependencies(source, snapshots, task_map)
      snapshots.each do |snapshot|
        task = task_map[snapshot[:id].to_s]
        desired = Array(snapshot[:depends_on]).filter_map do |ledger_id|
          user.tasks.find_by(origin_session_key: task_origin_key(source.profile, ledger_id.to_s))
        end
        sync_task_dependencies(task, desired)
      end
    end

    def sync_task_dependencies(task, desired)
      desired_ids = desired.map(&:id)
      task.task_dependencies.where.not(depends_on_id: desired_ids).destroy_all
      desired.each { |dependency| task.task_dependencies.find_or_create_by!(depends_on: dependency) }
    end

    def sync_events(source, events, accepted)
      events.each do |event|
        task = find_task!(source, event[:task_id])
        run = run_for_event(task, source, event)
        attributes = event_attributes(task, run, event)
        if AgentActivityEvent.exists?(run_id: run.run_id, seq: attributes[:seq])
          accepted[:duplicates] += 1
        else
          AgentActivityEvent.create!(attributes)
          accepted[:events] += 1
        end
      rescue ActiveRecord::RecordNotUnique
        accepted[:duplicates] += 1
      end
    end

    def event_attributes(task, run, event)
      {
        task:,
        run_id: run.run_id,
        seq: positive_integer(event[:seq], "event seq"),
        source: "wezbridge",
        event_type: normalize_event_type(event[:event_type]),
        level: normalize_level(event[:level]),
        message: PayloadSanitizer.text(event[:message]),
        payload: PayloadSanitizer.call(event[:payload] || {}).merge(
          "external_id" => PayloadSanitizer.text(event[:external_id], maximum: 200)
        ),
        created_at: parse_time(event[:timestamp], allow_blank: true) || Time.current
      }
    end

    def sync_messages(source, messages, accepted)
      messages.each do |message|
        task = find_task!(source, message[:task_id])
        external_id = required_text(message[:external_id], "message external_id", 200)
        if message_exists?(task, external_id)
          accepted[:duplicates] += 1
          next
        end

        task.agent_messages.create!(message_attributes(message, external_id))
        accepted[:messages] += 1
      end
    end

    def message_attributes(message, external_id)
      provenance = message[:provenance].to_s
      raise InvalidRequest, "message provenance is invalid" unless %w[operator orchestrator worker].include?(provenance)

      {
        direction: provenance == "operator" ? "outgoing" : "incoming",
        message_type: normalize_message_type(message[:message_type]),
        content: required_text(PayloadSanitizer.text(message[:content]), "message content", 100_000),
        sender_name: PayloadSanitizer.text(message[:sender_name], maximum: 100).presence || provenance.titleize,
        metadata: {
          "external_id" => external_id,
          "provenance" => provenance,
          "source" => "wezbridge",
          "source_timestamp" => message[:timestamp]
        }
      }
    end

    def sync_intent_results(source, results, accepted)
      results.each do |item|
        intent = user.orchestration_intents.find_by!(id: item[:id], orchestration_source: source)
        status = item[:status].to_s
        raise InvalidRequest, "intent result status is invalid" unless %w[applied rejected].include?(status)

        if intent.status != "pending"
          accepted[:duplicates] += 1
          next
        end

        result = PayloadSanitizer.call(item[:result] || {})
        intent.update!(status:, result:, processed_at: Time.current, task: result_task(source, result) || intent.task)
        accepted[:intent_results] += 1
      end
    end

    def result_task(source, result)
      origin_key = result["task_origin_key"].presence
      origin_key ||= task_origin_key(source.profile, result["ledger_id"]) if result["ledger_id"].present?
      origin_key ||= task_origin_key(source.profile, result["task_id"]) if result["task_id"].present?
      user.tasks.find_by(origin_session_key: origin_key) if origin_key.present?
    end

    def projection_board
      board = user.boards.find_by(id: DEFAULT_BOARD_ID)
      raise InvalidRequest, "Board #{DEFAULT_BOARD_ID} is unavailable" unless board
      raise InvalidRequest, "The ALL aggregator cannot receive mirrored work" if board.aggregator?

      board
    end

    def find_task!(source, ledger_id)
      user.tasks.find_by!(origin_session_key: task_origin_key(source.profile, ledger_id.to_s))
    end

    def run_for_event(task, source, event)
      attempt = positive_integer(event[:attempt].presence || 1, "event attempt")
      ledger_id = task.origin_session_id
      find_or_create_run(task, source, ledger_id, attempt)
    end

    def message_exists?(task, external_id)
      task.agent_messages.where("metadata ->> 'external_id' = ?", external_id).exists?
    end

    def normalize_source_status(value)
      status = value.to_s
      OrchestrationSource::STATUSES.include?(status) ? status : "healthy"
    end

    def normalize_priority(value)
      case value.to_s
      when "3", "high", "urgent", "p0", "p1" then :high
      when "2", "medium", "normal", "p2" then :medium
      when "1", "low", "p3" then :low
      else :none
      end
    end

    def normalize_event_type(value)
      type = value.to_s
      AgentActivityEvent::EVENT_TYPES.include?(type) ? type : "status"
    end

    def normalize_level(value)
      level = value.to_s
      AgentActivityEvent::LEVELS.include?(level) ? level : "info"
    end

    def normalize_message_type(value)
      case value.to_s
      when "result", "output" then "output"
      when "error" then "error"
      else "feedback"
      end
    end

    def orchestration_tags(snapshot)
      ["orchestration", PayloadSanitizer.text(snapshot[:project], maximum: 100).presence].compact
    end

    def task_origin_key(profile, ledger_id)
      "wezbridge:#{profile}:task:#{valid_identifier(ledger_id, 'task id', 80)}"
    end

    def valid_identifier(value, field, maximum)
      identifier = value.to_s
      valid = identifier.present? && identifier.length <= maximum && identifier.match?(IDENTIFIER_PATTERN)
      raise InvalidRequest, "#{field} is invalid" unless valid

      identifier
    end

    def valid_state(value)
      state = value.to_s
      raise InvalidRequest, "task state is invalid" unless SOURCE_STATES.include?(state)

      state
    end

    def required_text(value, field, maximum)
      text = value.to_s.strip
      raise InvalidRequest, "#{field} is required" if text.blank?
      raise InvalidRequest, "#{field} is too long" if text.length > maximum

      text
    end

    def parse_time(value, allow_blank: false)
      return if allow_blank && value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidRequest, "timestamp is invalid"
    end

    def positive_integer(value, field)
      integer = Integer(value)
      raise InvalidRequest, "#{field} is invalid" unless integer.positive?

      integer
    rescue ArgumentError, TypeError
      raise InvalidRequest, "#{field} is invalid"
    end

    def terminal_state?(state)
      %w[done failed cancelled].include?(state)
    end

    def next_run_number(task)
      (task.task_runs.maximum(:run_number) || 0) + 1
    end
  end
end
