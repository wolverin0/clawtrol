# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @boards = current_user.boards.includes(:user).order(position: :asc)

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
      format.json { render json: { tasks: @tasks.map { |t| { id: t.id, name: t.name, status: t.status, board_id: t.board_id, board_name: t.board.name } } } }
    end
  end
end
