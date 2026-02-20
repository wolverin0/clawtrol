# frozen_string_literal: true

class LearningProposalsController < ApplicationController
  def index
    @learning_proposals = current_user.learning_proposals.pending_first
    @learning_proposals = @learning_proposals.where(status: status_filter) if status_filter.present?
    @status_counts = current_user.learning_proposals.group(:status).count.each_with_object({}) do |(key, value), counts|
      status_name = key.is_a?(String) ? key : LearningProposal.statuses.key(key)
      counts[status_name || key.to_s] = value
    end
  end

  def approve
    @learning_proposal = current_user.learning_proposals.find(params[:id])
    @learning_proposal.apply!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to learning_proposals_path, notice: "Proposal approved." }
    end
  end

  def reject
    @learning_proposal = current_user.learning_proposals.find(params[:id])
    @learning_proposal.reject!(reason: params[:reason])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to learning_proposals_path, notice: "Proposal rejected." }
    end
  end

  private

  def status_filter
    status = params[:status]
    return if status.blank?
    return unless LearningProposal.statuses.key?(status)

    status
  end
end
