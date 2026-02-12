class ApiToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :name, presence: true

  before_validation :generate_token, on: :create

  def self.authenticate(token)
    return nil if token.blank?

    api_token = find_by(token: token)
    return nil unless api_token

    api_token.touch(:last_used_at)
    api_token.user
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
