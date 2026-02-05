class ApiToken < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :name, presence: true

  # The raw token is only available immediately after creation
  attr_accessor :raw_token

  before_validation :generate_and_hash_token, on: :create

  # Authenticate by hashing the incoming token and looking up the digest
  def self.authenticate(token)
    return nil if token.blank?

    digest = Digest::SHA256.hexdigest(token)
    api_token = find_by(token_digest: digest)
    return nil unless api_token

    api_token.touch(:last_used_at)
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
