# frozen_string_literal: true

class FactoryFindingPattern < ApplicationRecord
  belongs_to :factory_loop, optional: true, inverse_of: :factory_finding_patterns

  validates :pattern_hash, presence: true, uniqueness: { scope: :factory_loop_id }
  validates :description, presence: true

  scope :active, -> { where(suppressed: false) }
  scope :suppressed, -> { where(suppressed: true) }

  def accept!
    attrs = { suppressed: false }
    attrs[:accepted] = true if has_attribute?(:accepted)
    attrs[:accepted_at] = Time.current if has_attribute?(:accepted_at)
    attrs[:dismissed_at] = nil if has_attribute?(:dismissed_at)
    update!(attrs)
  end

  def dismiss!
    attrs = { dismiss_count: dismiss_count.to_i + 1, suppressed: true }
    attrs[:accepted] = false if has_attribute?(:accepted)
    attrs[:dismissed_at] = Time.current if has_attribute?(:dismissed_at)
    update!(attrs)
  end

  def review_state
    return "accepted" if has_attribute?(:accepted) && accepted?
    return "dismissed" if suppressed?

    "pending"
  end

  def confidence_score
    return self[:confidence_score].to_i if has_attribute?(:confidence_score) && self[:confidence_score].present?
    return (confidence.to_f * 100).round if has_attribute?(:confidence) && confidence.present?
    return [[(occurrences.to_i * 15), 95].min, 5].max if has_attribute?(:occurrences)

    50
  end
end
