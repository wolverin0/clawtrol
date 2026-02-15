# frozen_string_literal: true

class Workflow < ApplicationRecord
  validates :title, presence: true

  validate :definition_must_be_hash

  private

  def definition_must_be_hash
    return if definition.is_a?(Hash)
    errors.add(:definition, "must be a JSON object")
  end
end
