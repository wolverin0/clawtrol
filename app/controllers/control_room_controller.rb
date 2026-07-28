# frozen_string_literal: true

class ControlRoomController < ApplicationController
  before_action :set_task, only: %i[thread message approve retry cancel]
  helper_method :pane_display_status

  def show
    @full_width_page = true
    @sources = current_user.orchestration_sources.most_recent
    @source = selected_source(@sources)
    @project_options = project_options(@source)
    @tasks = projected_tasks.includes(:agent_messages).order(updated_at: :desc).limit(250)
    @pending_intents = current_user.orchestration_intents.pending.limit(100)
    categorize_tasks
    @selected_task = selected_task
  end

  def create_task
    create_task_intent(kind: "task")
  end

  def thread
    render partial: "thread_messages", locals: { task: @task }
  end

  def ask
    create_task_intent(kind: "question")
  end

  def message
    source = source_for_task!(@task)
    content = required_param(:content, maximum: 100_000)

    intent = ApplicationRecord.transaction do
      record = create_intent(source, "message", @task, { "content" => content })
      record_operator_message(@task, record, content)
      record
    end

    redirect_to control_room_path(task_id: @task.id),
      notice: "Message queued as intent ##{intent.id}."
  rescue Orchestration::InvalidRequest => e
    redirect_to control_room_path(task_id: @task.id), alert: e.message
  end

  %i[approve retry cancel].each do |action|
    define_method(action) do
      source = source_for_task!(@task)
      intent = create_intent(source, action.to_s, @task, {})
      redirect_to control_room_path(task_id: @task.id),
        notice: "#{action.to_s.titleize} queued as intent ##{intent.id}."
    rescue Orchestration::InvalidRequest => e
      redirect_to control_room_path(task_id: @task.id), alert: e.message
    end
  end

  private

  def projected_tasks
    current_user.tasks.where("origin_session_key LIKE 'wezbridge:%'")
  end

  def selected_source(sources)
    return sources.find_by(id: params[:source_id]) if params[:source_id].present?

    sources.first
  end

  def project_options(source)
    Array(source&.panes).filter_map do |pane|
      project = pane["project"].to_s.strip
      next if project.blank?

      pane_id = pane["pane_id"] || pane["id"]
      status = pane_display_status(pane)
      ["pane #{pane_id} — #{project} (#{status})", project]
    end.uniq { |option| option.last }
  end

  def pane_display_status(pane)
    status = (pane["status"] || pane["state"]).to_s
    status.blank? || status == "unknown" ? "present" : status
  end

  def categorize_tasks
    @needs_attention = @tasks.select { |task| task.blocked? || task.needs_decision? }
    @failures = @tasks.select { |task| source_state(task) == "failed" }
    @active = @tasks.select { |task| %w[queued ready running review].include?(source_state(task)) && !task.blocked? }
    @recent = @tasks.select { |task| %w[done cancelled].include?(source_state(task)) }.first(25)
  end

  def selected_task
    return if params[:task_id].blank?

    @tasks.find { |task| task.id == params[:task_id].to_i }
  end

  def create_task_intent(kind:)
    source = source_for_create!
    brief = required_param(:brief, maximum: 2_000)
    title = params[:title].to_s.strip.presence || brief.truncate(120)
    payload = {
      "title" => title.truncate(500),
      "brief" => brief,
      "project" => required_param(:project, maximum: 200),
      "kind" => kind,
      "priority" => params[:priority].presence || "normal",
      "acceptance" => params[:acceptance].to_s.strip.truncate(2_000)
    }
    intent = create_intent(source, "create_task", nil, payload)

    redirect_to control_room_path(source_id: source.id),
      notice: "#{kind == 'question' ? 'Question' : 'Task'} queued as intent ##{intent.id}."
  rescue Orchestration::InvalidRequest => e
    redirect_to control_room_path, alert: e.message
  end

  def create_intent(source, kind, task, payload)
    payload = payload.merge("task_id" => task.origin_session_id) if task
    current_user.orchestration_intents.create!(
      orchestration_source: source,
      task:,
      kind:,
      payload: Orchestration::PayloadSanitizer.call(payload)
    )
  end

  def record_operator_message(task, intent, content)
    task.agent_messages.create!(
      direction: "outgoing",
      message_type: "feedback",
      content: Orchestration::PayloadSanitizer.text(content),
      sender_name: "You",
      metadata: {
        "external_id" => "clawtrol-intent:#{intent.id}",
        "intent_id" => intent.id,
        "provenance" => "operator",
        "source" => "clawtrol"
      }
    )
  end

  def set_task
    @task = projected_tasks.find(params[:task_id])
  end

  def source_for_create!
    source = current_user.orchestration_sources.find_by(id: params[:source_id])
    source ||= current_user.orchestration_sources.most_recent.first
    raise Orchestration::InvalidRequest, "Connect the Wezbridge bridge first." unless source

    source
  end

  def source_for_task!(task)
    profile = task.state_data.dig("orchestration", "profile")
    source = current_user.orchestration_sources.find_by(profile:)
    raise Orchestration::InvalidRequest, "The task's orchestration source is unavailable." unless source

    source
  end

  def required_param(name, maximum:)
    value = params[name].to_s.strip
    raise Orchestration::InvalidRequest, "#{name.to_s.humanize} is required." if value.blank?
    raise Orchestration::InvalidRequest, "#{name.to_s.humanize} is too long." if value.length > maximum

    value
  end

  def source_state(task)
    task.state_data.dig("orchestration", "source_state").to_s
  end
end
