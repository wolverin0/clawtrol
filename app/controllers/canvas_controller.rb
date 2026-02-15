# frozen_string_literal: true

class CanvasController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication
  before_action :ensure_gateway_configured!

  # GET /canvas
  def show
    @nodes = fetch_nodes
    @templates = canvas_templates
  end

  # POST /canvas/push
  def push
    node_id = params[:node_id].to_s.strip
    html_content = params[:html_content].to_s.strip
    width = params[:width].presence&.to_i
    height = params[:height].presence&.to_i

    if node_id.blank? || html_content.blank?
      respond_to do |format|
        format.html { redirect_to canvas_path, alert: "Node and HTML content are required" }
        format.json { render json: { error: "Node and HTML content are required" }, status: :unprocessable_entity }
      end
      return
    end

    # Sanitize: reject script tags and event handlers to prevent XSS on target node
    if html_content.match?(/<script[\s>]/i) || html_content.match?(/\bon\w+\s*=/i)
      respond_to do |format|
        format.html { redirect_to canvas_path, alert: "Script tags and event handlers are not allowed" }
        format.json { render json: { error: "Script tags and event handlers are not allowed" }, status: :unprocessable_entity }
      end
      return
    end

    result = gateway_client.canvas_push(
      node: node_id,
      html: html_content,
      width: width,
      height: height
    )

    if result[:error].present?
      respond_to do |format|
        format.html { redirect_to canvas_path, alert: "Push failed: #{result[:error]}" }
        format.json { render json: { error: result[:error] }, status: :unprocessable_entity }
      end
    else
      respond_to do |format|
        format.html { redirect_to canvas_path, notice: "Canvas pushed to #{node_id} successfully" }
        format.json { render json: { success: true, node: node_id } }
      end
    end
  end

  # POST /canvas/snapshot
  def snapshot
    node_id = params[:node_id].to_s.strip

    if node_id.blank?
      render json: { error: "Node ID is required" }, status: :unprocessable_entity
      return
    end

    result = gateway_client.canvas_snapshot(node: node_id)

    if result[:error].present?
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: { success: true, snapshot: result }
    end
  end

  # POST /canvas/hide
  def hide
    node_id = params[:node_id].to_s.strip

    if node_id.blank?
      render json: { error: "Node ID is required" }, status: :unprocessable_entity
      return
    end

    result = gateway_client.canvas_hide(node: node_id)

    if result[:error].present?
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: { success: true }
    end
  end

  # GET /canvas/templates
  def templates
    render json: canvas_templates
  end

  private

  def fetch_nodes
    data = Rails.cache.fetch("canvas/nodes/#{current_user.id}", expires_in: 15.seconds) do
      gateway_client.nodes_status
    end
    Array(data["nodes"] || data[:nodes] || [])
  rescue StandardError => e
    Rails.logger.warn("[Canvas] Failed to fetch nodes: #{e.message}")
    []
  end

  def canvas_templates
    [
      {
        id: "task_summary",
        name: "📋 Task Summary",
        description: "Shows active tasks with status counts",
        html: task_summary_template
      },
      {
        id: "factory_progress",
        name: "🏭 Factory Progress",
        description: "Current factory cycle status and recent improvements",
        html: factory_progress_template
      },
      {
        id: "cost_dashboard",
        name: "💰 Cost Summary",
        description: "Agent session costs for today",
        html: cost_summary_template
      },
      {
        id: "system_status",
        name: "🖥️ System Status",
        description: "Gateway health + channel connectivity",
        html: system_status_template
      },
      {
        id: "clock_widget",
        name: "🕐 Clock Widget",
        description: "Simple clock with date display",
        html: clock_widget_template
      }
    ]
  end

  def task_summary_template
    counts = if current_user
      Task.where(user_id: current_user.id)
           .group(:status)
           .count
    else
      {}
    end

    <<~HTML
      <div style="font-family: system-ui, -apple-system, sans-serif; padding: 16px; background: #1a1a2e; color: #eee; border-radius: 12px;">
        <h2 style="margin: 0 0 12px; font-size: 18px; color: #e94560;">📋 Task Summary</h2>
        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;">
          <div style="background: #16213e; padding: 10px; border-radius: 8px; text-align: center;">
            <div style="font-size: 24px; font-weight: bold; color: #0f3460;">#{counts.fetch("inbox", 0)}</div>
            <div style="font-size: 11px; color: #999;">Inbox</div>
          </div>
          <div style="background: #16213e; padding: 10px; border-radius: 8px; text-align: center;">
            <div style="font-size: 24px; font-weight: bold; color: #e94560;">#{counts.fetch("in_progress", 0)}</div>
            <div style="font-size: 11px; color: #999;">In Progress</div>
          </div>
          <div style="background: #16213e; padding: 10px; border-radius: 8px; text-align: center;">
            <div style="font-size: 24px; font-weight: bold; color: #ffc107;">#{counts.fetch("in_review", 0)}</div>
            <div style="font-size: 11px; color: #999;">In Review</div>
          </div>
          <div style="background: #16213e; padding: 10px; border-radius: 8px; text-align: center;">
            <div style="font-size: 24px; font-weight: bold; color: #4ecca3;">#{counts.fetch("done", 0)}</div>
            <div style="font-size: 11px; color: #999;">Done</div>
          </div>
        </div>
        <div style="margin-top: 8px; font-size: 10px; color: #666; text-align: right;">
          Updated: #{Time.current.strftime("%H:%M")}
        </div>
      </div>
    HTML
  end

  def factory_progress_template
    recent = FactoryCycleLog.order(created_at: :desc).limit(5)
    items = recent.map { |c| "<li>#{ERB::Util.html_escape(c.category)}: #{ERB::Util.html_escape(c.description&.truncate(60))}</li>" }.join

    <<~HTML
      <div style="font-family: system-ui, -apple-system, sans-serif; padding: 16px; background: #0d1117; color: #c9d1d9; border-radius: 12px;">
        <h2 style="margin: 0 0 12px; font-size: 18px; color: #58a6ff;">🏭 Factory Progress</h2>
        <ul style="margin: 0; padding-left: 20px; font-size: 13px; line-height: 1.6;">
          #{items.presence || "<li>No recent cycles</li>"}
        </ul>
        <div style="margin-top: 8px; font-size: 10px; color: #484f58; text-align: right;">
          Total cycles: #{FactoryCycleLog.count}
        </div>
      </div>
    HTML
  end

  def cost_summary_template
    today_snapshots = CostSnapshot.where("created_at >= ?", Time.current.beginning_of_day)
    total_cost = today_snapshots.sum(:cost_usd)

    <<~HTML
      <div style="font-family: system-ui, -apple-system, sans-serif; padding: 16px; background: #1b2838; color: #c6d4df; border-radius: 12px;">
        <h2 style="margin: 0 0 12px; font-size: 18px; color: #66c0f4;">💰 Cost Today</h2>
        <div style="text-align: center; padding: 12px;">
          <div style="font-size: 36px; font-weight: bold; color: #a4d007;">$#{"%.2f" % total_cost}</div>
          <div style="font-size: 12px; color: #8f98a0; margin-top: 4px;">
            #{today_snapshots.count} sessions tracked
          </div>
        </div>
      </div>
    HTML
  end

  def system_status_template
    <<~HTML
      <div style="font-family: system-ui, -apple-system, sans-serif; padding: 16px; background: #161b22; color: #c9d1d9; border-radius: 12px;">
        <h2 style="margin: 0 0 12px; font-size: 18px; color: #3fb950;">🖥️ System Status</h2>
        <div style="font-size: 14px; line-height: 1.8;">
          <div>🟢 Gateway: Online</div>
          <div>🟢 ClawTrol: Running</div>
          <div>📊 Time: #{Time.current.strftime("%Y-%m-%d %H:%M")}</div>
        </div>
      </div>
    HTML
  end

  def clock_widget_template
    <<~HTML
      <div style="font-family: 'SF Mono', monospace; padding: 20px; background: #000; color: #0f0; border-radius: 12px; text-align: center;">
        <div style="font-size: 48px; font-weight: bold; letter-spacing: 4px;">
          #{Time.current.strftime("%H:%M")}
        </div>
        <div style="font-size: 14px; margin-top: 8px; color: #0a0;">
          #{Time.current.strftime("%A, %B %d")}
        </div>
      </div>
    HTML
  end
end
