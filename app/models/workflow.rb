# frozen_string_literal: true

class Workflow < ApplicationRecord
  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :workflows

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }, allow_nil: true
  validates :slug, length: { maximum: 100 }, format: { with: /\A[a-z0-9_-]+\z/ }, allow_nil: true
  validates :category, length: { maximum: 50 }, allow_nil: true
  validates :status, length: { maximum: 50 }, inclusion: { in: %w[draft active paused completed archived], allow_nil: true }

  scope :for_user, ->(user) { where(user_id: [user.id, nil]) }
  scope :active, -> { where(status: "active") }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }

  validate :definition_must_be_hash

  private

  def definition_must_be_hash
    return if definition.is_a?(Hash)
    errors.add(:definition, "must be a JSON object")
  end
end
