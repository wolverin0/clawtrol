# frozen_string_literal: true

class ApiToken < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :user, inverse_of: :user

  validates :token_digest, presence: true, uniqueness: true
  validates :name, presence: true

  # The raw token is only available immediately after creation
  attr_accessor :raw_token

  before_validation :generate_and_hash_token, on: :create

  # Authenticate by hashing the incoming token and looking up the digest.
  # Uses periodic touch (every 60s) to avoid a DB write on every API request.
  LAST_USED_DEBOUNCE = 60.seconds

  def self.authenticate(token)
    return nil if token.blank?

    digest = Digest::SHA256.hexdigest(token)
    api_token = find_by(token_digest: digest)
    return nil unless api_token

    # Debounce last_used_at writes to reduce DB load under high request volume
    if api_token.last_used_at.nil? || api_token.last_used_at < LAST_USED_DEBOUNCE.ago
      api_token.touch(:last_used_at)
    end

    api_token.user
  end

  # For display: show a masked prefix (first 8 chars) if token_prefix is stored
  def masked_token
    if token_prefix.present?
      "#{token_prefix}#{'•' * 56}"
    else
      "#{'•' * 64}"
    end
  end

  private

  def generate_and_hash_token
    raw = SecureRandom.hex(32)
    self.raw_token = raw
    self.token_digest = Digest::SHA256.hexdigest(raw)
    self.token_prefix = raw[0..7]
  end
end
