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
end
