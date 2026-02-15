# frozen_string_literal: true

module Api
  module V1
    class SavedLinksController < BaseController
      before_action :set_saved_link, only: [:update]

      # GET /api/v1/saved_links
      def index
        links = current_user.saved_links.newest_first
        render json: links
      end

      # POST /api/v1/saved_links
      def create
        link = current_user.saved_links.build(saved_link_params)
        if link.save
          render json: link, status: :created
        else
          render json: { error: link.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/saved_links/pending
      def pending
        links = current_user.saved_links.where(status: [:pending, :processing]).newest_first
        render json: links
      end

      # PATCH /api/v1/saved_links/:id
      def update
        if @saved_link.update(update_params)
          render json: @saved_link
        else
          render json: { error: @saved_link.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_saved_link
        @saved_link = current_user.saved_links.find(params[:id])
      end

      def saved_link_params
        params.permit(:url, :note, :deep_summary, :summary_file_path)
      end

      def update_params
        params.permit(
          :note,
          :summary,
          :raw_content,
          :status,
          :processed_at,
          :error_message,
          :deep_summary,
          :summary_file_path
        )
      end
    end
  end
end
