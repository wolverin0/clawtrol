# frozen_string_literal: true

module AgentPlatforms
  # Base class for agent platform adapters (OpenClaw, Hermes, future backends).
  #
  # Subclasses implement what they actually support and inherit safe defaults
  # for everything else (returns Result.unsupported(...)). Controllers and
  # services should never branch on the platform identity — they call the
  # adapter and inspect the Result status instead.
  class BaseAdapter
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # --- Identity ---
    def key = raise NotImplementedError
    def label = key.to_s.titleize
    def available? = false

    # --- Status ---
    def health = Result.unsupported(platform: key)

    # --- Sessions ---
    def sessions_list = Result.unsupported(platform: key)
    def session_detail(_session_key) = Result.unsupported(platform: key)
    def spawn_session!(model:, prompt:) = Result.unsupported(platform: key)
    def sessions_send(_session_key, _message) = Result.unsupported(platform: key)
    def sessions_history(_session_key, limit: 20) = Result.unsupported(platform: key)

    # --- Cron ---
    def cron_list(all: true) = Result.unsupported(platform: key)
    def cron_create(_params) = Result.unsupported(platform: key)
    def cron_update(_id, _params) = Result.unsupported(platform: key)
    def cron_delete(_id) = Result.unsupported(platform: key)
    def cron_pause(_id) = Result.unsupported(platform: key)
    def cron_resume(_id) = Result.unsupported(platform: key)
    def cron_run(_id) = Result.unsupported(platform: key)

    # --- Models / config ---
    def models_list = Result.unsupported(platform: key)
    def current_model = Result.unsupported(platform: key)
    def config_get = Result.unsupported(platform: key)

    # --- File roots ---
    # Returns Hash of logical prefix => absolute Pathname, e.g.
    #   { "openclaw" => Pathname("/home/ggorbalan/.openclaw/workspace") }
    def file_roots = {}
  end
end
