# frozen_string_literal: true

class OpenclawIntegrationStatus < ApplicationRecord
  belongs_to :user

  enum :memory_search_status, {
    unknown: 0,
    ok: 1,
    degraded: 2,
    down: 3
  }, prefix: :memory_search

  validates :user_id, uniqueness: true
  validates :memory_search_status, presence: true, inclusion: { in: %w[unknown ok degraded down] }

  scope :active, -> { where.not(memory_search_status: "down") }
  scope :degraded, -> { where(memory_search_status: "degraded") }
  scope :ok_status, -> { where(memory_search_status: "ok") }
end
