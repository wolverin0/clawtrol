# frozen_string_literal: true

require "ostruct"

class ProfilesController < ApplicationController
  def show
    @user = current_user
    @api_token = current_user.api_token
  end

  def test_connection
    render json: { error: "direct agent control retired" }, status: :gone
  end

  def test_notification
    # Build a duck-type task object that ExternalNotificationService expects:
    # must respond to .user, .id, .name, .status, .description, .origin_chat_id, .origin_thread_id
    fake_task = OpenStruct.new(
      id: 0,
      user: current_user,
      name: "Test Notification",
      status: "in_review",
      description: "This is a test notification from ClawTrol",
      origin_chat_id: current_user.telegram_chat_id,
      origin_thread_id: nil
    )

    svc = ExternalNotificationService.new(fake_task)
    svc.notify_task_completion

    render json: { success: true }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
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
    # Store raw token in flash for one-time display.
    # SECURITY: Use a separate flash key so it's rendered in a dedicated
    # copy-friendly UI element, not as a generic notice visible in logs/referrer.
    flash[:new_api_token] = @api_token.raw_token
    redirect_to settings_path, notice: "API token regenerated. Copy it now — it won't be shown again!"
  end

  private

  def profile_params
    params.expect(user: [ :email_address, :avatar, :ai_suggestion_model, :ai_api_key, :context_threshold_percent, :auto_retry_enabled, :auto_retry_max, :auto_retry_backoff, :fallback_model_chain, :agent_name, :agent_emoji, :theme, :telegram_bot_token, :telegram_chat_id, :webhook_notification_url, :notifications_enabled ])
  end
end
