module Api
  module V1
    class CommentsController < BaseController
      before_action :set_task

      # GET /api/v1/tasks/:task_id/comments
      def index
        @comments = @task.comments

        render json: @comments.map { |comment| comment_json(comment) }
      end

      # POST /api/v1/tasks/:task_id/comments
      def create
        @comment = @task.comments.new(comment_params)

        if @comment.save
          render json: comment_json(@comment), status: :created
        else
          render json: { error: @comment.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_task
        @task = current_user.tasks.find(params[:task_id])
      end

      def comment_params
        params.require(:comment).permit(:author_type, :author_name, :body)
      end

      def comment_json(comment)
        {
          id: comment.id,
          task_id: comment.task_id,
          author_type: comment.author_type,
          author_name: comment.author_name,
          body: comment.body,
          created_at: comment.created_at.iso8601,
          updated_at: comment.updated_at.iso8601
        }
      end
    end
  end
end
