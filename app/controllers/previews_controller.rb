class PreviewsController < ApplicationController
  include OutputRenderable

  before_action :set_task, only: [:show, :raw]

  def index
    @tasks = current_user.tasks
      .not_archived
      .where(status: [:in_review, :done])
      .where(
        "jsonb_array_length(output_files) > 0 OR description LIKE ?",
        "%## Agent Output%"
      )
      .order(updated_at: :desc)
      .limit(50)
      .includes(:board, :agent_persona)
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
end
