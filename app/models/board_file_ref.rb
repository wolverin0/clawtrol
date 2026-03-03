# frozen_string_literal: true

class BoardFileRef < ApplicationRecord
  belongs_to :board

  CATEGORIES = %w[general docs scripts reports notes config].freeze
  HIDDEN_PATTERN = /(?:^|\/)\.[^\/]/

  validates :path, presence: true, length: { maximum: 1000 }, uniqueness: { scope: :board_id }
  validates :label, length: { maximum: 255 }, allow_blank: true
  validates :category, presence: true, length: { maximum: 50 }, format: { with: /\A[a-z0-9_\-]+\z/ }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :path_must_be_safe

  before_validation :normalize_fields

  scope :ordered, -> { order(:category, :position, :created_at) }

  def display_label
    label.presence || path
  end

  private

  def normalize_fields
    self.path = path.to_s.strip.sub(%r{\A/+}, "")
    self.category = category.to_s.strip.downcase.presence || "general"
    self.label = label.to_s.strip.presence
  end

  def path_must_be_safe
    if path.blank?
      errors.add(:path, "can't be blank")
      return
    end

    if path.include?("\x00") || path.start_with?("/") || path.start_with?("~") || path.include?("//")
      errors.add(:path, "is invalid")
      return
    end

    if path.match?(HIDDEN_PATTERN)
      errors.add(:path, "cannot include dotfiles or dot-directories")
      return
    end

    components = path.split("/")
    if components.any? { |component| component.blank? || component == "." || component == ".." }
      errors.add(:path, "cannot include traversal segments")
      return
    end

    return if allowed_in_board_project_path?(path)
    return if allowed_in_global_viewer_dirs?(path)

    errors.add(:path, "must be within board project path or allowed viewer directories")
  end

  def allowed_in_board_project_path?(raw_path)
    return false if board.blank? || board.project_path.blank?

    base = File.expand_path(board.project_path)
    candidate = File.expand_path(File.join(base, raw_path))

    candidate.start_with?(base + "/") || candidate == base
  end

  def allowed_in_global_viewer_dirs?(raw_path)
    allowed_dirs = FileViewerController::ALLOWED_DIRS.map(&:to_s)

    allowed_dirs.any? do |dir|
      base_name = File.basename(dir)
      candidate = if raw_path == base_name || raw_path.start_with?("#{base_name}/")
        suffix = raw_path == base_name ? "" : raw_path.delete_prefix("#{base_name}/")
        File.expand_path(File.join(dir, suffix))
      else
        File.expand_path(File.join(FileViewerController::WORKSPACE.to_s, raw_path))
      end

      candidate.start_with?(dir + "/") || candidate == dir
    end
  end
end
