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
      webhook_configured: false
    }

    gateway_url = @user.openclaw_gateway_url
    gateway_token = @user.openclaw_gateway_token

    # Check if gateway URL and token are configured
    results[:webhook_configured] = gateway_url.present? && gateway_token.present?

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

        # If gateway is reachable and we have a token, try to validate it
        if results[:gateway_reachable] && gateway_token.present?
          # Try the sessions endpoint to validate token
          sessions_uri = URI.parse("#{gateway_url}/api/sessions")
          sessions_request = Net::HTTP::Get.new(sessions_uri)
          sessions_request["Authorization"] = "Bearer #{gateway_token}"

          sessions_response = http.request(sessions_request)
          results[:token_valid] = [ 200, 401 ].exclude?(sessions_response.code.to_i) || sessions_response.code.to_i == 200
        end
      rescue StandardError => e
        results[:error] = e.message
      end
    end

    render json: results
  end

  def update
    @user = current_user

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
    params.expect(user: [ :email_address, :avatar, :openclaw_gateway_url, :openclaw_gateway_token, :ai_suggestion_model, :ai_api_key, :context_threshold_percent, :auto_retry_enabled, :auto_retry_max, :auto_retry_backoff, :fallback_model_chain, :agent_name, :agent_emoji ])
  end
end
