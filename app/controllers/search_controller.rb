class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @boards = current_user.boards

    if @query.present?
      search_term = "%#{@query}%"
      @tasks = current_user.tasks
        .joins(:board)
        .where("tasks.name ILIKE ? OR tasks.description ILIKE ?", search_term, search_term)
        .not_archived
        .includes(:board, :user)
        .order(updated_at: :desc)
        .limit(50)

      # Group by board for display
      @tasks_by_board = @tasks.group_by(&:board)
    else
      @tasks = []
      @tasks_by_board = {}
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
