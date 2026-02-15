# frozen_string_literal: true

class OpenclawIntegrationStatus < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :openclaw_integration_statuses

  enum :memory_search_status, {
    unknown: 0,
    ok: 1,
    degraded: 2,
    down: 3
  }, prefix: :memory_search

  validates :user_id, uniqueness: true
end
