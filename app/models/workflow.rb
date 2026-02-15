class Workflow < ApplicationRecord
  belongs_to :user, optional: true

  validates :title, presence: true

  scope :for_user, ->(user) { where(user_id: [user.id, nil]) }

  validate :definition_must_be_hash

  private

  def definition_must_be_hash
    return if definition.is_a?(Hash)
    errors.add(:definition, "must be a JSON object")
  end
end
