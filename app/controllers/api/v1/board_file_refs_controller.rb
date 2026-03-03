# frozen_string_literal: true

module Api
  module V1
    class BoardFileRefsController < BaseController
      before_action :set_board
      before_action :set_file_ref, only: [:destroy]

      def index
        refs = @board.file_refs.ordered
        render json: refs.map { |ref| file_ref_json(ref) }
      end

      def create
        ref = @board.file_refs.new(file_ref_params)
        if ref.save
          render json: file_ref_json(ref), status: :created
        else
          render json: { error: ref.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      def destroy
        @file_ref.destroy
        head :no_content
      end

      private

      def set_board
        @board = current_user.boards.find(params[:board_id])
      end

      def set_file_ref
        @file_ref = @board.file_refs.find(params[:id])
      end

      def file_ref_params
        params.permit(:path, :label, :category, :position)
      end

      def file_ref_json(ref)
        {
          id: ref.id,
          board_id: ref.board_id,
          path: ref.path,
          label: ref.label,
          category: ref.category,
          position: ref.position,
          created_at: ref.created_at.iso8601,
          updated_at: ref.updated_at.iso8601
        }
      end
    end
  end
end
