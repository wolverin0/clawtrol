# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password validations: false

  # Enforce eager loading to prevent N+1 queries in views
  # Use strict_loading_mode :strict to raise on N+1, :n_plus_one to only warn
  strict_loading :n_plus_one

  THEMES = %w[default vaporwave].freeze

  has_many :sessions, dependent: :destroy, inverse_of: :user
  has_many :boards, dependent: :destroy, inverse_of: :user
  has_many :tasks, dependent: :destroy, inverse_of: :user
  has_many :task_templates, dependent: :destroy, inverse_of: :user
  has_many :api_tokens, dependent: :destroy, inverse_of: :user
  has_many :saved_links, dependent: :destroy, inverse_of: :user
  has_many :feed_entries, dependent: :destroy, inverse_of: :user
  has_many :model_limits, dependent: :destroy, inverse_of: :user
  has_many :notifications, dependent: :destroy, inverse_of: :user
  has_many :agent_personas, dependent: :destroy, inverse_of: :user
  has_many :swarm_ideas, dependent: :destroy, inverse_of: :user
  has_many :nightshift_missions, dependent: :nullify, inverse_of: :user
  has_many :invite_codes, foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by
  has_many :factory_loops, dependent: :nullify, inverse_of: :user
  has_many :workflows, dependent: :nullify, inverse_of: :user
  has_many :webhook_logs, dependent: :delete_all, inverse_of: :user
  has_many :cost_snapshots, dependent: :delete_all, inverse_of: :user
  has_many :agent_test_recordings, dependent: :destroy, inverse_of: :user
  has_many :audit_reports, dependent: :destroy, inverse_of: :user
  has_many :behavioral_interventions, dependent: :destroy, inverse_of: :user
  has_one_attached :avatar
  has_one :openclaw_integration_status, dependent: :destroy, inverse_of: :user

  # Security: encrypt sensitive fields at rest using Rails 7+ built-in encryption
  encrypts :ai_api_key
  encrypts :telegram_bot_token
  encrypts :openclaw_gateway_token
  encrypts :openclaw_hooks_token

  # Encrypted attributes can contain legacy/corrupt ciphertext after key rotations.
  # Fail safe so dashboard and runners stay available instead of crashing requests/jobs.
  %i[ai_api_key telegram_bot_token openclaw_gateway_token openclaw_hooks_token].each do |encrypted_attr|
    define_method(encrypted_attr) do
      super()
    rescue ActiveRecord::Encryption::Errors::Decryption, ActiveRecord::Encryption::Errors::EncryptedContentIntegrity
      nil
    end
  end

  # Primary API token for agent integration
  # Note: raw_token is only available on the returned object if the token was just created
  def api_token
    api_tokens.first || api_tokens.create!(name: "Default")
  end

  # Create a new API token, returning an object with raw_token available
  def regenerate_api_token!
    api_tokens.destroy_all
    api_tokens.create!(name: "Default")
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validate :acceptable_avatar, if: :avatar_changed?
  validate :webhook_url_is_safe, if: -> { webhook_notification_url.present? }
  validate :gateway_url_is_valid, if: -> { openclaw_gateway_url.present? }
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?
  validates :theme, inclusion: { in: THEMES }
  validates :agent_name, length: { maximum: 100 }, allow_nil: true
  validates :agent_emoji, length: { maximum: 10 }, allow_nil: true
  validates :openclaw_gateway_url, length: { maximum: 2048 }, allow_nil: true
  validates :openclaw_gateway_token, length: { maximum: 2048 }, allow_nil: true
  validates :openclaw_hooks_token, length: { maximum: 2048 }, allow_nil: true
  validates :telegram_chat_id, length: { maximum: 50 }, allow_nil: true
  validates :ai_suggestion_model, length: { maximum: 50 }, allow_nil: true
  validates :context_threshold_percent, numericality: { only_integer: true, greater_than_or_equal_to: 10, less_than_or_equal_to: 100 }

  after_create_commit :create_onboarding_board

  validates :email_address, presence: true,
                           uniqueness: { case_sensitive: false },
                           format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  # Check if GitHub OAuth is configured
  def self.github_oauth_enabled?
    ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
  end

  # Find or create a user from GitHub OAuth data
  def self.find_or_create_from_github(auth)
    email = auth.info.email
    github_avatar_url = auth.info.image
    user = find_by(email_address: email)

    if user
      # Link existing user to GitHub if not already linked
      if user.provider.nil?
        user.update(provider: "github", uid: auth.uid)
      end
      # Update avatar URL if user doesn't have one
      user.update(avatar_url: github_avatar_url) if github_avatar_url.present? && user.avatar_url.blank?
      user
    else
      # Create new user from GitHub with avatar URL
      create(
        email_address: email,
        provider: "github",
        uid: auth.uid,
        avatar_url: github_avatar_url
      )
    end
  end

  # Returns avatar source - Active Storage attachment takes priority over URL
  def avatar_source
    if avatar.attached?
      avatar
    elsif avatar_url.present?
      avatar_url
    end
  end

  def has_avatar?
    avatar.attached? || avatar_url.present?
  end

  # Check if user signed up via OAuth
  def oauth_user?
    provider.present?
  end

  # Check if user has a password set
  def password_user?
    password_digest.present?
  end

  # Check if user needs to set a password (OAuth user without password)
  def needs_password?
    oauth_user? && !password_user?
  end

  private

  def password_required?
    # Password is required for new non-OAuth users or when password is being set
    !oauth_user? && (new_record? || password.present?)
  end

  def create_onboarding_board
    Board.create_onboarding_for(self)
  end

  def avatar_changed?
    avatar.attached? && avatar.attachment.new_record?
  end

  def acceptable_avatar
    return unless avatar.attached?
    return unless avatar.blob.present?

    unless avatar.blob.byte_size <= 512.kilobytes
      errors.add(:avatar, "is too large (maximum is 512KB)")
    end

    acceptable_types = [ "image/jpeg", "image/jpg", "image/png", "image/webp" ]
    unless acceptable_types.include?(avatar.blob.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, or WebP")
    end

    return unless avatar.blob.representable?
    return unless avatar.blob.metadata.present?

    metadata = avatar.blob.metadata
    width = metadata[:width]
    height = metadata[:height]

    if width.present? && height.present? && (width > 256 || height > 256)
      errors.add(:avatar, "dimensions must not exceed 256x256 pixels")
    end
  end

  # SSRF prevention: reject internal/private network URLs for webhook notifications.
  # Users could set webhook_notification_url to internal services (DB, Redis, metadata).
  PRIVATE_HOST_PATTERNS = [
    /\A127\./,           # loopback IPv4
    /\A10\./,            # private 10.x
    /\A172\.(1[6-9]|2\d|3[0-1])\./, # private 172.16-31.x
    /\A192\.168\./,      # private 192.168.x
    /\A0\./,             # 0.0.0.0/8
    /\Alocalhost\z/i,    # localhost
    /\A\[?::1\]?\z/,     # IPv6 loopback
    /\A169\.254\./,      # link-local
    /\.internal\z/i,     # internal TLDs
    /\.local\z/i         # mDNS
  ].freeze

  def gateway_url_is_valid
    uri = URI.parse(openclaw_gateway_url) rescue nil
    unless uri.is_a?(URI::HTTP)
      errors.add(:openclaw_gateway_url, "must be a valid http(s) URL")
    end
  end

  def webhook_url_is_safe
    uri = URI.parse(webhook_notification_url) rescue nil

    unless uri.is_a?(URI::HTTP)
      errors.add(:webhook_notification_url, "must be a valid http(s) URL")
      return
    end

    host = uri.host.to_s.downcase
    if PRIVATE_HOST_PATTERNS.any? { |pattern| host.match?(pattern) }
      errors.add(:webhook_notification_url, "must not point to internal/private network addresses")
    end
  end
end
