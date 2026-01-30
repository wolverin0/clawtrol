class User < ApplicationRecord
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validate :acceptable_avatar, if: :avatar_changed?
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  after_create :create_welcome_tasks

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
    user = find_by(email_address: email)

    if user
      # Link existing user to GitHub if not already linked
      if user.provider.nil?
        user.update(provider: "github", uid: auth.uid)
      end
      user
    else
      # Create new user from GitHub
      create(
        email_address: email,
        provider: "github",
        uid: auth.uid
      )
    end
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

  def create_welcome_tasks
    [
      { name: "Welcome to ClawDeck!", status: :inbox, priority: :high },
      { name: "Create your first task", status: :inbox, priority: :medium },
      { name: "Drag tasks between columns", status: :up_next, priority: :low },
      { name: "Use tags to organize tasks", status: :up_next, priority: :low, tags: ["tutorial"] },
      { name: "Join the Discord community", status: :inbox, priority: :high }
    ].each do |task_attrs|
      tasks.create!(task_attrs)
    end
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
end
