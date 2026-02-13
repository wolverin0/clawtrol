# frozen_string_literal: true

class ShowcasesController < ApplicationController
  include OutputRenderable

  before_action :set_task, only: [:show, :raw, :toggle_winner]

  # Known product tags for filtering
  PRODUCT_TAGS = %w[FuturaCRM FuturaFitness OptimaDelivery Nightshift ClawTrol].freeze

  def index
    @tasks = fetch_showcase_tasks
    @tasks_by_week = group_by_week(@tasks)
    @products = extract_products(@tasks)
  end

  def show
    @preview_content = extract_preview_content(@task)
    @preview_type = @preview_content[:type]
  end

  # Serve raw HTML content for iframe embedding
  # Accepts optional ?file= param to serve specific file (for multi-variant tasks)
  def raw
    if params[:file].present?
      # Serve specific file by path
      content = read_html_file_by_path(@task, params[:file])
    else
      # Default: serve first HTML file
      content = read_first_html_file(@task)
    end

    if content
      # html_safe is intentional: agent-generated HTML served in sandboxed iframe
      # Security boundary is sandbox="allow-scripts allow-same-origin" in parent view
      render html: content.html_safe, layout: false
    else
      render plain: "No HTML content available", status: :not_found
    end
  end

  # Toggle winner status via PATCH
  def toggle_winner
    @task.update!(showcase_winner: !@task.showcase_winner)

    respond_to do |format|
      format.html { redirect_to showcases_path, notice: @task.showcase_winner ? "⭐ Marked as winner!" : "Winner status removed" }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "showcase-card-#{@task.id}",
          partial: "showcases/card",
          locals: { task: @task, product: product_for_task(@task) }
        )
      end
    end
  end

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  def fetch_showcase_tasks
    # Base query: in_review or done, not archived, with output
    base_scope = current_user.tasks
      .not_archived
      .where(status: [:in_review, :done])
      .where(
        "jsonb_array_length(output_files) > 0 OR description LIKE ?",
        "%## Agent Output%"
      )
      .includes(:board, :agent_persona)

    # TIGHT filter for redesign/mockup content only:
    # 1. Tags contain "redesign", "mockup", or "landing-page" (specific tags, not generic)
    # 2. OR board_id=17 (Marketing board)
    # 3. OR name starts with "redesign-" or contains "landing page"
    #
    # REMOVED: generic "design", "marketing", "visual", "ui" — too broad, matches ops tasks
    base_scope
      .where(<<~SQL, board_id: 17)
        (tags::text ILIKE '%redesign%' OR tags::text ILIKE '%mockup%' OR tags::text ILIKE '%landing-page%')
        OR board_id = :board_id
        OR name ~* '^redesign-'#{' '}
        OR name ILIKE '%landing page%'
      SQL
      .order(updated_at: :desc)
      .limit(100)
  end

  def group_by_week(tasks)
    tasks.group_by { |task| task.updated_at.beginning_of_week(:monday) }
         .sort_by { |week, _| week }
         .reverse
         .to_h
  end

  def extract_products(tasks)
    products = tasks.flat_map { |t| t.tags || [] }
                    .select { |tag| PRODUCT_TAGS.any? { |p| tag.to_s.downcase.include?(p.downcase) } }
                    .map { |tag| PRODUCT_TAGS.find { |p| tag.to_s.downcase.include?(p.downcase) } }
                    .compact
                    .uniq
    products.presence || []
  end

  def extract_product_tag(task)
    return nil unless task.tags.present?

    task.tags.find do |tag|
      PRODUCT_TAGS.any? { |p| tag.to_s.downcase.include?(p.downcase) }
    end
  end
  helper_method :extract_product_tag

  def product_for_task(task)
    return nil unless task.tags.present?

    PRODUCT_TAGS.find do |product|
      task.tags.any? { |tag| tag.to_s.downcase.include?(product.downcase) }
    end
  end
  helper_method :product_for_task
end
