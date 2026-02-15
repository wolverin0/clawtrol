# frozen_string_literal: true

module Api
  module V1
    class BoardsController < BaseController
      before_action :set_board, only: [ :show, :update, :destroy, :status ]

      # GET /api/v1/boards
      def index
        @boards = current_user.boards.order(position: :asc, created_at: :asc)
        render json: @boards.map { |board| board_json(board) }
      end

      # GET /api/v1/boards/:id
      def show
        render json: board_json(@board, include_tasks: params[:include_tasks] == "true")
      end

      # GET /api/v1/boards/:id/status
      # Lightweight endpoint for polling - returns a fingerprint based on task state
      def status
        tasks = if @board.aggregator?
          current_user.tasks
            .joins(:board)
            .where(boards: { is_aggregator: false })
            .not_archived
        else
          @board.tasks.not_archived
        end

        # Build a fingerprint from task count and latest modification
        task_count = tasks.count
        latest_update_time = tasks.maximum(:updated_at)
        latest_update = latest_update_time&.to_i || 0

        # Include status counts for more granular change detection
        status_counts = tasks.group(:status).count

        # Create a fingerprint hash
        fingerprint_data = "#{task_count}-#{latest_update}-#{status_counts.to_json}"
        fingerprint = Digest::MD5.hexdigest(fingerprint_data)

        render json: {
          fingerprint: fingerprint,
          task_count: task_count,
          updated_at: latest_update_time&.iso8601
        }
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
        params.permit(:name, :icon, :color, :auto_claim_enabled, :auto_claim_prefix, auto_claim_tags: [])
      end

      def board_json(board, include_tasks: false)
        json = {
          id: board.id,
          name: board.name,
          icon: board.icon,
          color: board.color,
          tasks_count: board.tasks_count,
          auto_claim_enabled: board.auto_claim_enabled,
          auto_claim_tags: board.auto_claim_tags || [],
          auto_claim_prefix: board.auto_claim_prefix,
          last_auto_claim_at: board.last_auto_claim_at&.iso8601,
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
