# frozen_string_literal: true

class WebchatController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication

  # GET /webchat
  # Embeds the OpenClaw webchat iframe with optional task context injection.
  def show
    @webchat_url = webchat_base_url
    @task = current_user.tasks.find_by(id: params[:task_id]) if params[:task_id].present?

    # Build context query params for the webchat iframe
    @iframe_url = build_iframe_url
  end

  private

  def webchat_base_url
    # Prefer user-configured gateway URL, fall back to default webchat port
    gateway_url = current_user&.openclaw_gateway_url.to_s.strip
    if gateway_url.present?
      uri = URI.parse(gateway_url)
      # Webchat runs on a separate port (18789) on the same host
      "#{uri.scheme}://#{uri.host}:18789"
    else
      "http://localhost:18789"
    end
  rescue URI::InvalidURIError
    "http://localhost:18789"
  end

  def build_iframe_url
    url = @webchat_url.dup

    if @task
      # Inject context: tell the agent which task the user is looking at
      context = "I'm looking at task ##{@task.id}: #{@task.name}"
      url += "?context=#{CGI.escape(context)}"
    end

    url
  end
end
