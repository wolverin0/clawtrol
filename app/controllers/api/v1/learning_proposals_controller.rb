# frozen_string_literal: true

module Api
  module V1
    class LearningProposalsController < BaseController
      before_action :set_learning_proposal, only: [:update, :approve, :reject]

      # GET /api/v1/learning_proposals
      def index
        proposals = current_user.learning_proposals.newest_first
        proposals = proposals.where(status: params[:status]) if status_filter.present?
        render json: proposals
      end

      # POST /api/v1/learning_proposals
      def create
        proposal = current_user.learning_proposals.build(learning_proposal_params)
        if proposal.save
          render json: proposal, status: :created
        else
          render json: { error: proposal.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/learning_proposals/:id
      def update
        if @learning_proposal.update(update_params)
          render json: @learning_proposal
        else
          render json: { error: @learning_proposal.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/learning_proposals/:id/approve
      def approve
        @learning_proposal.apply!
        render json: @learning_proposal
      end

      # POST /api/v1/learning_proposals/:id/reject
      def reject
        @learning_proposal.reject!(reason: params[:reason])
        render json: @learning_proposal
      end

      private

      def set_learning_proposal
        @learning_proposal = current_user.learning_proposals.find(params[:id])
      end

      def learning_proposal_params
        params.permit(
          :title,
          :proposed_by,
          :target_file,
          :current_content,
          :proposed_content,
          :diff_preview,
          :reason
        )
      end

      def update_params
        params.permit(
          :title,
          :proposed_by,
          :target_file,
          :current_content,
          :proposed_content,
          :diff_preview,
          :status,
          :reason
        )
      end

      def status_filter
        status = params[:status]
        return if status.blank?
        return unless LearningProposal.statuses.key?(status)

        status
      end
    end
  end
end
