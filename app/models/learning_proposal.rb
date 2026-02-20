# frozen_string_literal: true

require "fileutils"

class LearningProposal < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :learning_proposals

  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  validates :title, :target_file, :proposed_content, presence: true

  WORKSPACE_ROOT = File.expand_path("~/.openclaw/workspace")

  scope :newest_first, -> { order(created_at: :desc) }
  scope :pending_first, -> { order(status: :asc, created_at: :desc) }

  def apply!
    target_path = resolved_target_path
    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, proposed_content)
    update!(status: :approved)
  end

  def reject!(reason: nil)
    update!(status: :rejected, reason: reason)
  end

  private

  def resolved_target_path
    full_path = File.expand_path(target_file, WORKSPACE_ROOT)
    return full_path if full_path.start_with?(WORKSPACE_ROOT + File::SEPARATOR)

    raise ArgumentError, "Target file must live under workspace root"
  end
end
