# frozen_string_literal: true

class PreviewsController < ApplicationController
  include OutputRenderable

  OUTPUTS_LIMIT = 200
  OUTPUT_STATUS_OPTIONS = %w[in_review done].freeze

  before_action :require_authentication
  before_action :set_task, only: [:show, :raw]

  def index
    @query = params[:q].to_s.strip
    @board_filter = params[:board_id].to_s.presence
    @status_filter = params[:status].to_s.presence
    @owner_filter = params[:owner_id].to_s.presence
    @campaign_filter = params[:campaign].to_s.strip.presence
    @date_from = parse_date(params[:date_from])
    @date_to = parse_date(params[:date_to])

    @boards = current_user.boards.order(position: :asc)
    @owners = AgentPersona.for_user(current_user).active.order(:name)
    @campaign_options = derive_campaign_options

    base = scoped_outputs_relation

    @tasks = base
      .order(updated_at: :desc)
      .limit(OUTPUTS_LIMIT)
      .includes(:board, :agent_persona)

    @tasks_by_board = @tasks.group_by(&:board)

    @result_stats = {
      total: @tasks.size,
      with_files: @tasks.count { |task| task.output_files.present? },
      with_agent_output: @tasks.count { |task| task.has_agent_output? },
      in_review: @tasks.count(&:in_review?),
      done: @tasks.count(&:done?)
    }

    respond_to do |format|
      format.html
      format.json { render json: outputs_payload }
    end
  end

  def show
    @preview_content = extract_preview_content(@task)
    @preview_type = @preview_content[:type]
  end

  # Serve raw HTML content for iframe embedding
  def raw
    content = read_first_html_file(@task)
    if content
      # html_safe is intentional: agent-generated HTML served in sandboxed iframe
      # Security boundary is sandbox="allow-scripts allow-same-origin" in parent view
      render html: content.html_safe, layout: false
    else
      render plain: "No HTML content available", status: :not_found
    end
  end

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  def scoped_outputs_relation
    relation = current_user.tasks
      .not_archived
      .where(status: OUTPUT_STATUS_OPTIONS)
      .where("jsonb_array_length(output_files) > 0 OR description LIKE ?", "%## Agent Output%")

    relation = relation.where(board_id: @board_filter) if @board_filter.present?

    if @status_filter.present? && OUTPUT_STATUS_OPTIONS.include?(@status_filter)
      relation = relation.where(status: @status_filter)
    end

    relation = relation.where(agent_persona_id: @owner_filter) if @owner_filter.present?

    if @campaign_filter.present?
      campaign_query = "%#{@campaign_filter}%"
      relation = relation.where(
        "array_to_string(tasks.tags, ' ') ILIKE :q OR tasks.name ILIKE :q OR tasks.description ILIKE :q",
        q: campaign_query
      )
    end

    relation = relation.where("tasks.updated_at >= ?", @date_from.beginning_of_day) if @date_from
    relation = relation.where("tasks.updated_at <= ?", @date_to.end_of_day) if @date_to

    if @query.present?
      query = "%#{@query}%"
      relation = relation.where(
        "tasks.name ILIKE :q OR tasks.description ILIKE :q OR CAST(tasks.output_files AS text) ILIKE :q OR array_to_string(tasks.tags, ' ') ILIKE :q",
        q: query
      )
    end

    relation
  end

  def derive_campaign_options
    tags = current_user.tasks
      .not_archived
      .where(status: OUTPUT_STATUS_OPTIONS)
      .where("jsonb_array_length(output_files) > 0 OR description LIKE ?", "%## Agent Output%")
      .limit(1000)
      .pluck(:tags)
      .flatten
      .compact

    tags.filter_map do |tag|
      next unless tag.to_s.start_with?("campaign:")
      tag.to_s.split(":", 2).last.presence
    end.uniq.sort
  end

  def parse_date(value)
    return nil if value.blank?
    Date.iso8601(value.to_s)
  rescue StandardError
    nil
  end

  def outputs_payload
    {
      filters: {
        q: @query,
        board_id: @board_filter,
        status: @status_filter,
        owner_id: @owner_filter,
        campaign: @campaign_filter,
        date_from: @date_from&.iso8601,
        date_to: @date_to&.iso8601
      },
      total: @tasks.size,
      stats: @result_stats,
      tasks: @tasks.map do |task|
        {
          id: task.id,
          board_id: task.board_id,
          board_name: task.board&.name,
          name: task.name,
          status: task.status,
          owner_id: task.agent_persona_id,
          owner_name: task.agent_persona&.name,
          tags: task.tags,
          output_files_count: Array(task.output_files).size,
          updated_at: task.updated_at.iso8601
        }
      end
    }
  end
end
