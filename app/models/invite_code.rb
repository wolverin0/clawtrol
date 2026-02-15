# frozen_string_literal: true

class InviteCode < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :created_by, class_name: "User"

  validates :code, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :available, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }

  before_validation :generate_code, on: :create

  def available?
    used_at.nil?
  end

  def redeem!(user_email = nil)
    update!(used_at: Time.current, email: user_email || email)
  end

  private

  def generate_code
    self.code ||= SecureRandom.alphanumeric(8).upcase
  end
end
