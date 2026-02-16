# frozen_string_literal: true

# Catastrophic guardrails: detect empty/dropped DB or abrupt count drops.
#
# Env:
# - CLAWDECK_GUARDRAILS_ENABLED=true|false
# - CLAWDECK_GUARDRAILS_MODE=alert_only|fail_fast
# - CLAWDECK_GUARDRAILS_INTERVAL_SECONDS=300 (optional, enables periodic checks)
# - CLAWDECK_GUARDRAILS_DROP_PERCENT=50 (optional)
# - CLAWTROL_TELEGRAM_BOT_TOKEN=... (required to send alerts)
# - CLAWTROL_TELEGRAM_ALERT_CHAT_ID=... (required to send alerts)

return unless ENV["CLAWDECK_GUARDRAILS_ENABLED"].to_s == "true"

Rails.application.config.after_initialize do
  begin
    # Run once after boot; if interval is set, the job will self-reschedule.
    CatastrophicGuardrailsJob.perform_later(source: "boot")
  rescue StandardError => e
    Rails.logger.warn("[Guardrails] boot enqueue failed: #{e.class}: #{e.message}")
  end
end
