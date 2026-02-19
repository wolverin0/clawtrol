# frozen_string_literal: true

# Serves the Telegram Mini App — a self-contained, standalone page
# that runs inside Telegram's WebApp container.
#
# No Rails session auth required; instead, we validate Telegram's
# initData (HMAC-SHA256 signed by the bot token) on every API call.
#
# GET /telegram_app      → serves the HTML shell (standalone layout)
# POST /telegram_app/tasks  → list tasks (validated via initData)
# POST /telegram_app/tasks/create → quick-create a task
# POST /telegram_app/tasks/:id/approve → move to done
# POST /telegram_app/tasks/:id/reject  → move back to inbox
class TelegramMiniAppController < ActionController::Base
  # No CSRF for API-style calls from the Mini App JS
  skip_forgery_protection

  # Rate limit: 30 requests/minute per IP for API calls, 10/min for writes
  rate_limit to: 30, within: 1.minute, only: :tasks, with: -> { render_json_error("Rate limited", 429) }
  rate_limit to: 10, within: 1.minute, only: [:create_task, :approve, :reject], with: -> { render_json_error("Rate limited", 429) }

  VALID_STATUSES = Task.statuses.keys.freeze

  # No Rails auth — Telegram initData is the auth mechanism
  # But we do need the bot token configured
  before_action :require_bot_token, except: :show
  before_action :validate_telegram_user, except: :show

  layout false

  # GET /telegram_app
  # Serves the self-contained Mini App HTML page.
  # No auth needed here — the page itself has no data until JS calls the API.
  def show
    render :show
  end

  # POST /telegram_app/tasks
  # Returns tasks for the linked ClawTrol user.
  def tasks
    user = find_linked_user
    return render_json_error("No linked ClawTrol account", 403) unless user

    status_filter = params[:status].to_s.strip.presence
    tasks = user.tasks.order(updated_at: :desc).limit(50)
    if status_filter.present? && VALID_STATUSES.include?(status_filter)
      tasks = tasks.where(status: status_filter)
    end

    render json: {
      tasks: tasks.map { |t| mini_task_json(t) },
      user: { name: user.email_address, agent: user.agent_name }
    }
  end

  # POST /telegram_app/boards
  # Returns available boards for the linked user.
  def boards
    user = find_linked_user
    return render_json_error("No linked ClawTrol account", 403) unless user

    boards = user.boards.order(:name).select(:id, :name, :icon, :color)
    render json: { boards: boards.map { |b| { id: b.id, name: b.name, icon: b.icon, color: b.color } } }
  end

  # POST /telegram_app/tasks/create
  def create_task
    user = find_linked_user
    return render_json_error("No linked ClawTrol account", 403) unless user

    board = user.boards.find_by(id: params[:board_id]) || user.boards.first
    return render_json_error("No board found", 422) unless board

    name = params[:name].to_s.strip.truncate(500)
    return render_json_error("Title is required", 422) if name.blank?

    description = params[:description].to_s.strip.truncate(10_000).presence
    tags = AutoTaggerService.tag([name, description].compact.join(" "))

    task = board.tasks.new(
      name: name,
      description: description,
      status: :inbox,
      user: user,
      tags: tags.uniq.first(10),
      model: AutoTaggerService.suggest_model(tags),
      origin_chat_id: @tg_user["id"].to_s
    )
    OriginRoutingService.apply!(task, params: params, headers: request.headers)

    if task.save
      log_mini_app_action(user, "task_create", task)
      render json: { ok: true, task: mini_task_json(task) }
    else
      render_json_error(task.errors.full_messages.join(", "), 422)
    end
  end

  # POST /telegram_app/tasks/:id/approve
  # Moves a task to "done" status.
  def approve
    user = find_linked_user
    return render_json_error("No linked ClawTrol account", 403) unless user

    task = user.tasks.find_by(id: params[:id])
    return render_json_error("Task not found", 404) unless task

    task.update!(status: :done, completed: true, completed_at: Time.current)
    log_mini_app_action(user, "task_approve", task)
    render json: { ok: true, task: mini_task_json(task) }
  end

  # POST /telegram_app/tasks/:id/reject
  # Moves a task back to "inbox" with optional rejection note.
  def reject
    user = find_linked_user
    return render_json_error("No linked ClawTrol account", 403) unless user

    task = user.tasks.find_by(id: params[:id])
    return render_json_error("Task not found", 404) unless task

    note = params[:note].to_s.strip.truncate(2000).presence
    updates = { status: :inbox }
    if note
      updates[:description] = [task.description, "\n\n**Rejection note:** #{note}"].compact.join
    end

    task.update!(updates)
    log_mini_app_action(user, "task_reject", task)
    render json: { ok: true, task: mini_task_json(task) }
  end

  private

  def bot_token
    ENV["TELEGRAM_BOT_TOKEN"].presence || ENV["CLAWTROL_TELEGRAM_BOT_TOKEN"].presence
  end

  def require_bot_token
    render_json_error("Telegram bot token not configured", 500) unless bot_token
  end

  def validate_telegram_user
    init_data = params[:init_data] || request.headers["X-Telegram-Init-Data"]
    result = TelegramInitDataValidator.new(init_data, bot_token: bot_token).validate

    unless result.valid?
      render_json_error("Unauthorized: #{result.error}", 401)
      return
    end

    @tg_user = result.user
  end

  # Find the ClawTrol user linked to this Telegram user.
  # We match by telegram_chat_id stored on the user record,
  # or fall back to the first user (single-tenant mode).
  def find_linked_user
    return nil unless @tg_user

    tg_id = @tg_user["id"].to_s

    # Try matching by stored telegram ID
    user = User.find_by(telegram_chat_id: tg_id) if User.column_names.include?("telegram_chat_id")

    # Single-tenant fallback: if only one user exists, use them (cached 5 min)
    user ||= User.first if Rails.cache.fetch("telegram_mini_app/single_tenant", expires_in: 5.minutes) { User.count == 1 }

    user
  end

  def mini_task_json(task)
    TaskSerializer.new(task, mini: true).as_json
  end

  def render_json_error(message, status_code)
    render json: { ok: false, error: message }, status: status_code
  end

  # Audit trail: record Mini App actions as webhook logs
  def log_mini_app_action(user, event_type, task = nil)
    tg_info = @tg_user ? "tg:#{@tg_user['id']} (#{@tg_user['first_name']})" : "unknown"
    WebhookLog.record!(
      user: user,
      direction: "incoming",
      event_type: "telegram_mini_app_#{event_type}",
      endpoint: request.path,
      method: request.method,
      task: task,
      request_body: { telegram_user: tg_info, action: event_type },
      status_code: 200
    )
  rescue StandardError => e
    Rails.logger.warn("[TelegramMiniApp] Audit log failed: #{e.message}")
  end
end
