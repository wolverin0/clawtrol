# frozen_string_literal: true

class Workflow < ApplicationRecord
  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, optional: true, inverse_of: :workflows

  validates :title, presence: true

  scope :for_user, ->(user) { where(user_id: [user.id, nil]) }

  validate :definition_must_be_hash

  private

  def definition_must_be_hash
    return if definition.is_a?(Hash)
    errors.add(:definition, "must be a JSON object")
  end
end
