# frozen_string_literal: true

class BoardProjectFile < ApplicationRecord
  belongs_to :board, inverse_of: :project_files

  validates :file_path, presence: true
  validates :file_path, uniqueness: { scope: :board_id }
  validates :label, length: { maximum: 200 }, allow_nil: true
  validates :file_type, inclusion: { in: %w[auto markdown script config] }

  scope :pinned, -> { where(pinned: true) }
  scope :by_position, -> { order(:position, :id) }

  before_validation :set_defaults

  def display_name
    label.presence || File.basename(file_path.to_s)
  end

  def extension
    File.extname(file_path.to_s)
  end

  private

  def set_defaults
    self.file_type = "auto" if file_type.blank?
  end
end
