# frozen_string_literal: true

require "openssl"
require "cgi"
require "json"

# Validates Telegram Mini App initData using HMAC-SHA256.
#
# Telegram signs the initData string so the web app can verify it came
# from Telegram. See: https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
#
# Flow:
#   1. Parse the query string into key-value pairs
#   2. Remove the `hash` field
#   3. Sort remaining fields alphabetically
#   4. Build a "data-check-string" (key=value joined by \n)
#   5. HMAC-SHA256(secret_key, data_check_string) == hash
#
# The secret_key is HMAC-SHA256("WebAppData", bot_token).
class TelegramInitDataValidator
  # Maximum age of initData before it's considered expired (5 minutes)
  MAX_AGE_SECONDS = 300

  Result = Struct.new(:valid, :user, :error, keyword_init: true) do
    def valid? = valid
  end

  def initialize(init_data_raw, bot_token:)
    @raw = init_data_raw.to_s
    @bot_token = bot_token.to_s
  end

  def validate
    return Result.new(valid: false, error: "Missing initData") if @raw.blank?
    return Result.new(valid: false, error: "Missing bot token") if @bot_token.blank?

    params = parse_query_string(@raw)
    received_hash = params.delete("hash")

    return Result.new(valid: false, error: "Missing hash in initData") if received_hash.blank?

    # Check timestamp freshness
    auth_date = params["auth_date"].to_i
    if auth_date > 0 && (Time.now.to_i - auth_date) > MAX_AGE_SECONDS
      return Result.new(valid: false, error: "initData expired")
    end

    # Build data-check-string
    data_check_string = params.sort.map { |k, v| "#{k}=#{v}" }.join("\n")

    # Compute HMAC
    secret_key = OpenSSL::HMAC.digest("SHA256", "WebAppData", @bot_token)
    computed_hash = OpenSSL::HMAC.hexdigest("SHA256", secret_key, data_check_string)

    unless ActiveSupport::SecurityUtils.secure_compare(computed_hash, received_hash)
      return Result.new(valid: false, error: "Invalid hash")
    end

    # Parse user data
    user_data = params["user"].present? ? JSON.parse(params["user"]) : nil

    Result.new(valid: true, user: user_data)
  rescue JSON::ParserError
    Result.new(valid: false, error: "Invalid user JSON")
  end

  private

  def parse_query_string(qs)
    CGI.parse(qs).transform_values(&:first)
  end
end
