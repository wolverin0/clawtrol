require "ostruct"

class ProfilesController < ApplicationController
  def show
    @user = current_user
    @api_token = current_user.api_token
  end

  def test_connection
    @user = current_user
    results = {
      gateway_reachable: false,
      token_valid: false,
      hooks_token_valid: false,
      webhook_configured: false
    }

    gateway_url = @user.openclaw_gateway_url
    hooks_token = (@user.respond_to?(:openclaw_hooks_token) ? @user.openclaw_hooks_token : nil).to_s.strip
    legacy_token = @user.openclaw_gateway_token.to_s.strip
    token = hooks_token.presence || legacy_token

    # Check if gateway URL and token are configured
    results[:webhook_configured] = gateway_url.present? && token.present?

    if gateway_url.present?
      begin
        uri = URI.parse("#{gateway_url}/health")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 5
        http.read_timeout = 5
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        results[:gateway_reachable] = response.code.to_i == 200

        # Validate hooks token by calling the gateway hooks wake endpoint.
        if results[:gateway_reachable] && token.present?
          wake_uri = URI.parse("#{gateway_url}/hooks/wake")
          wake_request = Net::HTTP::Post.new(wake_uri)
          wake_request["Authorization"] = "Bearer #{token}"
          wake_request["Content-Type"] = "application/json"
          wake_request.body = { text: "ClawTrol connection test", mode: "next-heartbeat" }.to_json

          wake_response = http.request(wake_request)
          results[:hooks_token_valid] = wake_response.code.to_i == 200
          results[:token_valid] = results[:hooks_token_valid]
          results[:hooks_wake_code] = wake_response.code.to_i
        end
      rescue StandardError => e
        results[:error] = e.message
      end
    end

    render json: results
  end

  def test_notification
    svc = ExternalNotificationService.new(current_user)
    svc.notify_task_completion(
      OpenStruct.new(
        id: 0,
        name: "Test Notification",
        status: "in_review",
        description: "This is a test notification from ClawTrol"
      )
    )

    render json: { success: true }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def update
    @user = current_user

    normalize_agent_emoji_param!

    if params[:user][:remove_avatar] == "1"
      @user.avatar.purge if @user.avatar.attached?
      @user.avatar_url = nil
    end

    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def regenerate_api_token
    current_user.api_tokens.destroy_all
    @api_token = current_user.api_tokens.create!(name: "Default")
    # Flash the raw token so it can be shown once to the user
    redirect_to settings_path, notice: "API token regenerated. New token: #{@api_token.raw_token} — Copy it now, it won't be shown again!"
  end

  private

  def profile_params
    params.expect(user: [ :email_address, :avatar, :openclaw_gateway_url, :openclaw_gateway_token, :openclaw_hooks_token, :ai_suggestion_model, :ai_api_key, :context_threshold_percent, :auto_retry_enabled, :auto_retry_max, :auto_retry_backoff, :fallback_model_chain, :agent_name, :agent_emoji, :theme, :telegram_bot_token, :telegram_chat_id, :webhook_notification_url, :notifications_enabled ])
  end

  def normalize_agent_emoji_param!
    return unless params[:user].is_a?(ActionController::Parameters) || params[:user].is_a?(Hash)

    raw = params[:user][:agent_emoji]
    return if raw.blank?

    params[:user][:agent_emoji] = EmojiShortcodeNormalizer.normalize(raw)
  end
end
