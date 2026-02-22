# frozen_string_literal: true

require "set"

class QueueOrchestrationSelector
  Plan = Struct.new(:tasks, :skip_reasons, :available_slots, :max_concurrent, keyword_init: true)

  DEFAULT_MODEL_MAX_INFLIGHT = {
    "opus" => 2,
    "codex" => 2,
    "sonnet" => 2,
    "gemini3" => 3,
    "gemini3_flash" => 4,
    "glm" => 4
  }.freeze

  DEFAULT_PROVIDER_MAX_INFLIGHT = {
    "anthropic" => 3,
    "openai" => 3,
    "google" => 4,
    "zai" => 4
  }.freeze

  NIGHT_TZ = "America/Argentina/Buenos_Aires"

  def initialize(user, now: Time.current, logger: Rails.logger)
    @user = user
    @now = now
    @logger = logger
  end

  def available_slots
    [ max_concurrent - active_in_progress_scope.count, 0 ].max
  end

  def max_concurrent
    cfg = Rails.configuration.x.auto_runner
    night_value = cfg.max_concurrent_night.to_i
    day_value = cfg.max_concurrent_day.to_i
    in_night_window? ? [ night_value, 1 ].max : [ day_value, 1 ].max
  end

  def next_task
    plan(limit: 1).tasks.first
  end

  def plan(limit: nil)
    slots = available_slots
    requested = limit.present? ? [ limit.to_i, slots ].min : slots

    return Plan.new(tasks: [], skip_reasons: {}, available_slots: slots, max_concurrent: max_concurrent) if requested <= 0

    selected = []
    skip_reasons = Hash.new(0)
    selected_boards = Set.new

    boards_with_active_work = active_in_progress_scope.distinct.pluck(:board_id).to_set
    model_counts = Hash.new(0)
    provider_counts = Hash.new(0)

    active_in_progress_scope.pluck(:model).each do |model_name|
      normalized = normalize_model_name(model_name)
      model_counts[normalized] += 1
      provider_counts[provider_for_model(normalized)] += 1
    end

    active_model_limits = ModelLimit.active_limits.where(user: @user).pluck(:name).map { |name| normalize_model_name(name) }.to_set

    candidate_scope.each do |task|
      break if selected.length >= requested

      board_id = task.board_id
      if boards_with_active_work.include?(board_id) || selected_boards.include?(board_id)
        skip_reasons["board_busy"] += 1
        next
      end

      unless eligible_for_time_window?(task)
        skip_reasons["outside_time_window"] += 1
        next
      end

      normalized_model = normalize_model_name(task.model)
      provider = provider_for_model(normalized_model)

      if active_model_limits.include?(normalized_model)
        skip_reasons["model_rate_limited"] += 1
        next
      end

      if model_quota_exceeded?(normalized_model, model_counts)
        skip_reasons["model_quota_reached"] += 1
        next
      end

      if provider_quota_exceeded?(provider, provider_counts)
        skip_reasons["provider_quota_reached"] += 1
        next
      end

      selected << task
      selected_boards << board_id
      model_counts[normalized_model] += 1
      provider_counts[provider] += 1
    end

    Plan.new(
      tasks: selected,
      skip_reasons: skip_reasons,
      available_slots: slots,
      max_concurrent: max_concurrent
    )
  end

  def metrics
    active = active_in_progress_scope
    queue = candidate_scope

    inflight_by_model = Hash.new(0)
    inflight_by_provider = Hash.new(0)

    active.pluck(:model).each do |model_name|
      normalized = normalize_model_name(model_name)
      inflight_by_model[normalized] += 1
      inflight_by_provider[provider_for_model(normalized)] += 1
    end

    {
      now: @now.iso8601,
      in_night_window: in_night_window?,
      max_concurrent: max_concurrent,
      active_in_progress: active.count,
      available_slots: available_slots,
      queue_depth: queue.count,
      queue_depth_by_board: queue.unscope(:order).group(:board_id).count,
      inflight_by_model: inflight_by_model,
      inflight_by_provider: inflight_by_provider,
      model_limits_active: ModelLimit.active_limits.where(user: @user).pluck(:name)
    }
  end

  private

  def active_in_progress_scope
    @user.tasks.where(status: :in_progress, assigned_to_agent: true)
  end

  def candidate_scope
    cooldown = Rails.configuration.x.auto_runner.failure_cooldown_minutes.to_i.minutes

    @user.tasks
      .joins(:board)
      .where(status: :up_next, blocked: false, agent_claimed_at: nil, agent_session_id: nil, agent_session_key: nil)
      .where(assigned_to_agent: true, auto_pull_blocked: false)
      .where.not(recurring: true, parent_task_id: nil)
      .where(boards: { is_aggregator: false })
      .where("tasks.auto_pull_last_error_at IS NULL OR tasks.auto_pull_last_error_at < ?", @now - cooldown)
      .order("boards.position ASC, tasks.id ASC")
  end

  def model_quota_exceeded?(model_name, counts)
    limits = configured_model_limits
    max = limits[model_name]
    return false if max.nil?

    counts[model_name].to_i >= max.to_i
  end

  def provider_quota_exceeded?(provider_name, counts)
    limits = configured_provider_limits
    max = limits[provider_name]
    return false if max.nil?

    counts[provider_name].to_i >= max.to_i
  end

  def configured_model_limits
    raw = Rails.configuration.x.auto_runner.model_max_inflight
    return DEFAULT_MODEL_MAX_INFLIGHT if raw.blank?

    normalize_limit_hash(raw, fallback: DEFAULT_MODEL_MAX_INFLIGHT)
  end

  def configured_provider_limits
    raw = Rails.configuration.x.auto_runner.provider_max_inflight
    return DEFAULT_PROVIDER_MAX_INFLIGHT if raw.blank?

    normalize_limit_hash(raw, fallback: DEFAULT_PROVIDER_MAX_INFLIGHT)
  end

  def normalize_limit_hash(value, fallback:)
    source = case value
    when Hash
      value
    else
      {}
    end

    out = {}
    source.each do |key, amount|
      k = key.to_s.strip
      v = amount.to_i
      next if k.blank? || v <= 0

      out[k] = v
    end

    out.presence || fallback
  end

  def normalize_model_name(model_name)
    raw = model_name.to_s.strip.downcase
    return Task::DEFAULT_MODEL if raw.blank?

    return "gemini3_flash" if raw.match?(/gemini.*flash/) || raw == "flash"
    return "gemini3" if raw.start_with?("gemini3") || raw == "gemini"
    return "codex" if raw.include?("codex") || raw.start_with?("gpt-")
    return "sonnet" if raw.include?("sonnet")
    return "opus" if raw.include?("opus")
    return "glm" if raw.include?("glm")
    return "grok" if raw.include?("grok") || raw.include?("xai")
    return "ollama" if raw.include?("ollama")
    return "cerebras" if raw.include?("cerebras")
    raw
  end

  def provider_for_model(model_name)
    case model_name
    when /\A(opus|sonnet|claude)/
      "anthropic"
    when /\A(codex|gpt|openai)/
      "openai"
    when /\A(gemini|gemini3)/
      "google"
    when /\A(glm|zai)/
      "zai"
    when /\A(grok|xai)/
      "xai"
    when /\A(groq)/
      "groq"
    when /\A(ollama)/
      "ollama"
    when /\A(cerebras)/
      "cerebras"
    else
      "other"
    end
  end

  def in_night_window?
    now = @now.in_time_zone(NIGHT_TZ)
    start_hour = Rails.configuration.x.auto_runner.nightly_start_hour
    end_hour = Rails.configuration.x.auto_runner.nightly_end_hour

    if start_hour < end_hour
      now.hour >= start_hour && now.hour < end_hour
    else
      now.hour >= start_hour || now.hour < end_hour
    end
  end

  def eligible_for_time_window?(task)
    return true unless task.nightly?
    return false unless in_night_window?

    delay_hours = task.nightly_delay_hours.to_i
    return true if delay_hours <= 0

    now = @now.in_time_zone(NIGHT_TZ)
    start_hour = Rails.configuration.x.auto_runner.nightly_start_hour
    night_start_date = now.hour >= start_hour ? now.to_date : (now.to_date - 1.day)
    night_start = Time.find_zone!(NIGHT_TZ).local(
      night_start_date.year,
      night_start_date.month,
      night_start_date.day,
      start_hour,
      0,
      0
    )

    now >= (night_start + delay_hours.hours)
  end
end
