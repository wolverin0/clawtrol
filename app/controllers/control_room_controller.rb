# frozen_string_literal: true

class ControlRoomController < ApplicationController
  PROGRAM_KINDS = %w[bot-fix qa-oversight].freeze
  QUEUED_STATES = %w[queued ready].freeze
  WAITING_STATES = %w[failed review].freeze
  TERMINAL_STATES = %w[done cancelled].freeze

  before_action :set_task, only: %i[thread message approve retry cancel]
  helper_method :intent_result_summary, :pane_display_status, :orchestration_items,
    :task_needs_attention?

  def show
    @full_width_page = true
    load_control_room_state
    @selected_task = selected_task
  end

  def live
    load_control_room_state
    render partial: "live_payload"
  end

  def create_task
    create_task_intent(kind: "task")
  end

  def thread
    render partial: "thread_messages", locals: { task: @task }
  end

  def ask
    create_task_intent(kind: "question", default_project: "_fleet")
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

  def load_control_room_state
    @sources = current_user.orchestration_sources.most_recent
    @source = selected_source(@sources)
    @project_options = project_options(@source)
    @question_options = [["All open panes — fleet assessment", "_fleet"], *@project_options]
    @tasks = projected_tasks.includes(:agent_messages).order(updated_at: :desc).limit(250)
    @pending_intents = current_user.orchestration_intents.pending.limit(100)
    @recent_intents = current_user.orchestration_intents.recent.limit(12)
    categorize_tasks
  end

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

  def orchestration_items(value)
    Array.wrap(value).flat_map do |item|
      item.is_a?(Hash) ? item.map { |key, detail| "#{key}: #{detail}" } : item.to_s
    end.reject(&:blank?)
  end

  def task_needs_attention?(task)
    state = task.state_data.fetch("orchestration", {})
    task[:blocked] || # Mirrored FSM blocker; blocked? only checks dependency rows.
      task.blocked? ||
      task[:needs_decision] || # Canonical decision flag; the enum value is a legacy fallback.
      task.status == "needs_decision" ||
      (state["kind"] == "question" && !%w[done cancelled].include?(state["source_state"]))
  end

  def intent_result_summary(intent)
    result = intent.result.to_h
    summary = result["reason"] || result["error"] || result["message"]
    Orchestration::PayloadSanitizer.text(summary, maximum: 200).presence
  end

  def categorize_tasks
    grouped = @tasks.group_by { |task| task_lane(task) }
    @waiting_on_you = grouped.fetch(:waiting, [])
    @running_now = grouped.fetch(:running, [])
    @queued_next = grouped.fetch(:queued, [])
    @programs = grouped.fetch(:program, [])
    @unclassified_tasks = grouped.fetch(:unclassified, [])
    @recent = grouped.fetch(:recent, []).first(25)
    @project_work_counts = project_work_counts
  end

  def task_lane(task)
    return :recent if TERMINAL_STATES.include?(source_state(task))
    return :program if program_task?(task)
    return :waiting if task_needs_attention?(task) || WAITING_STATES.include?(source_state(task))
    return :running if source_state(task) == "running"
    return :queued if QUEUED_STATES.include?(source_state(task))

    :unclassified
  end

  def program_task?(task)
    state = task.state_data.fetch("orchestration", {})
    state["work_type"] == "program" || PROGRAM_KINDS.include?(state["kind"])
  end

  def project_work_counts
    lanes = {
      waiting: @waiting_on_you,
      running: @running_now,
      queued: @queued_next,
      program: @programs,
      unclassified: @unclassified_tasks
    }
    projects = lanes.values.flatten.filter_map { |task| task_project(task) }.uniq.sort

    projects.to_h do |project|
      [project, lanes.transform_values { |tasks| tasks.count { |task| task_project(task) == project } }]
    end
  end

  def task_project(task)
    task.state_data.dig("orchestration", "project").to_s.presence
  end

  def selected_task
    return if params[:task_id].blank?

    @tasks.find { |task| task.id == params[:task_id].to_i }
  end

  def create_task_intent(kind:, default_project: nil)
    source = source_for_create!
    brief = required_param(:brief, maximum: 2_000)
    title = params[:title].to_s.strip.presence || brief.truncate(120)
    payload = {
      "title" => title.truncate(500),
      "brief" => brief,
      "project" => params[:project].to_s.strip.presence || default_project ||
        required_param(:project, maximum: 200),
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
