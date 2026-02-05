class ProfilesController < ApplicationController
  def show
    @user = current_user
    @api_token = current_user.api_token
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
    @api_token = current_user.api_tokens.create!
    redirect_to settings_path, notice: "API token regenerated."
  end

  private

  def profile_params
    params.expect(user: [ :email_address, :avatar, :openclaw_gateway_url, :openclaw_gateway_token, :ai_suggestion_model, :ai_api_key, :context_threshold_percent, :auto_retry_enabled, :auto_retry_max, :auto_retry_backoff, :fallback_model_chain ])
  end
end
