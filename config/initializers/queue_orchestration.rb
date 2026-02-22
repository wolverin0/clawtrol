# frozen_string_literal: true

parse_limit_map = lambda do |raw|
  return {} if raw.to_s.strip.blank?

  raw.to_s.split(",").each_with_object({}) do |pair, out|
    key, value = pair.split(":", 2).map { |v| v.to_s.strip }
    next if key.blank?

    amount = value.to_i
    next if amount <= 0

    out[key] = amount
  end
end

Rails.application.configure do
  config.x.auto_runner.max_concurrent_day = ENV.fetch("AUTO_RUNNER_MAX_CONCURRENT_DAY", "6").to_i
  config.x.auto_runner.max_concurrent_night = ENV.fetch("AUTO_RUNNER_MAX_CONCURRENT_NIGHT", "8").to_i
  config.x.auto_runner.failure_cooldown_minutes = ENV.fetch("AUTO_RUNNER_FAILURE_COOLDOWN_MINUTES", "5").to_i
  config.x.auto_runner.stale_heartbeat_minutes = ENV.fetch("AUTO_RUNNER_STALE_HEARTBEAT_MINUTES", "20").to_i
  config.x.auto_runner.rate_limit_cooldown_minutes = ENV.fetch("AUTO_RUNNER_RATE_LIMIT_COOLDOWN_MINUTES", "10").to_i
  config.x.auto_runner.summary_interval_minutes = ENV.fetch("AUTO_RUNNER_SUMMARY_INTERVAL_MINUTES", "10").to_i

  config.x.auto_runner.model_max_inflight = parse_limit_map.call(ENV["AUTO_RUNNER_MODEL_MAX_INFLIGHT"])
  config.x.auto_runner.provider_max_inflight = parse_limit_map.call(ENV["AUTO_RUNNER_PROVIDER_MAX_INFLIGHT"])
end
