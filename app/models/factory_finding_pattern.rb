# frozen_string_literal: true

class FactoryFindingPattern < ApplicationRecord
  belongs_to :factory_loop, optional: true, inverse_of: :factory_finding_patterns

  validates :pattern_hash, presence: true, uniqueness: { scope: :factory_loop_id }
  validates :description, presence: true

  scope :active, -> { where(suppressed: false) }
  scope :suppressed, -> { where(suppressed: true) }

  def dismiss!
    increment!(:dismiss_count)
    update!(suppressed: true) if dismiss_count >= 2
  end
end
