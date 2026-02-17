# frozen_string_literal: true

class Workflow < ApplicationRecord
  # Use strict_loading_mode to detect N+1 queries in views
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :workflows

  validates :title, presence: true, length: { maximum: 255 }

  scope :for_user, ->(user) { where(user_id: [user&.id, nil]) }
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validate :definition_must_be_hash

  private

  def definition_must_be_hash
    return if definition.is_a?(Hash)
    errors.add(:definition, "must be a JSON object")
  end
end
