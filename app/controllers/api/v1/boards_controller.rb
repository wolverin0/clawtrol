module Api
  module V1
    class BoardsController < BaseController
      before_action :set_board, only: [ :show, :update, :destroy ]

      # GET /api/v1/boards
      def index
        @boards = current_user.boards.order(:created_at)
        render json: @boards.map { |board| board_json(board) }
      end

      # GET /api/v1/boards/:id
      def show
        render json: board_json(@board, include_tasks: params[:include_tasks] == "true")
      end

      # POST /api/v1/boards
      def create
        @board = current_user.boards.new(board_params)

        if @board.save
          render json: board_json(@board), status: :created
        else
          render json: { error: @board.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/boards/:id
      def update
        if @board.update(board_params)
          render json: board_json(@board)
        else
          render json: { error: @board.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/boards/:id
      def destroy
        if current_user.boards.count <= 1
          render json: { error: "Cannot delete your only board" }, status: :unprocessable_entity
        else
          @board.destroy!
          head :no_content
        end
      end

      private

      def set_board
        @board = current_user.boards.find(params[:id])
      end

      def board_params
        params.permit(:name, :icon, :color)
      end

      def board_json(board, include_tasks: false)
        json = {
          id: board.id,
          name: board.name,
          icon: board.icon,
          color: board.color,
          tasks_count: board.tasks.count,
          created_at: board.created_at.iso8601,
          updated_at: board.updated_at.iso8601
        }

        if include_tasks
          json[:tasks] = board.tasks.order(:status, :position).map do |task|
            {
              id: task.id,
              name: task.name,
              description: task.description,
              priority: task.priority,
              status: task.status,
              blocked: task.blocked,
              tags: task.tags || [],
              completed: task.completed,
              position: task.position,
              assigned_to_agent: task.assigned_to_agent
            }
          end
        end

        json
      end
    end
  end
end
