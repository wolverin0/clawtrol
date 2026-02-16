# frozen_string_literal: true

class InviteCode < ApplicationRecord
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  belongs_to :created_by, class_name: "User"

  validates :code, presence: true, uniqueness: true, length: { is: 8 }, format: { with: /\A[A-Z0-9]+\z/ }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :role, length: { maximum: 50 }, inclusion: { in: %w[admin user readonly], allow_nil: true }
  validates :max_uses, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1000 }, allow_nil: true
  validate :expires_at_in_future, if: -> { expires_at.present? }
  validate :uses_within_limit, if: -> { max_uses.present? }

  scope :available, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }

  before_validation :generate_code, on: :create

  def available?
    used_at.nil?
  end

  def redeem!(user_email = nil)
    update!(used_at: Time.current, email: user_email || email)
  end

  def uses_count
    # Placeholder for counting uses - implementation depends on design
    0
  end

  private

  def generate_code
    self.code ||= SecureRandom.alphanumeric(8).upcase
  end

  def expires_at_in_future
    return if expires_at.blank?
    if expires_at < Time.current
      errors.add(:expires_at, "must be in the future")
    end
  end

  def uses_within_limit
    return if max_uses.blank?
    if uses_count > max_uses
      errors.add(:max_uses, "cannot exceed maximum uses")
    end
  end
end
