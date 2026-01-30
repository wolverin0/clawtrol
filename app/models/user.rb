class User < ApplicationRecord
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_one :inbox_project, -> { where(inbox: true) }, class_name: "Project"
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validate :acceptable_avatar, if: :avatar_changed?
  validates :password, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  after_commit :send_admin_notification, on: :create
  after_create :create_inbox
  after_create :create_welcome_project

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

  # Get or create the user's inbox project
  def inbox
    inbox_project || create_inbox
  end

  private

  def password_required?
    # Password is required for new non-OAuth users or when password is being set
    !oauth_user? && (new_record? || password.present?)
  end

  def create_inbox
    projects.create!(title: "Inbox", inbox: true)
  end

  def send_admin_notification
    AdminMailer.new_user_signup(self).deliver_later
  end

  def create_welcome_project
    project = projects.create!(
      title: "Welcome to clawdeck",
      description: "This is your welcome project, a great place to start"
    )

    # Attach the clawdeck icon image
    image_path = Rails.root.join("app", "assets", "images", "clawdeckicon.png")
    if File.exist?(image_path)
      project.image.attach(
        io: File.open(image_path),
        filename: "clawdeckicon.png",
        content_type: "image/png"
      )
    end

    # Create tasks in the project's single task list
    task_list = project.default_task_list
    [
      { name: "Sign up to clawdeck", priority: :high },
      { name: "Create your first task", priority: :medium },
      { name: "Drag tasks around to reorder", priority: :low },
      { name: "Filter tasks by priority", priority: :low },
      { name: "Upload a project image", priority: :none },
      { name: "Join the discord community", priority: :high },
      { name: "Create your first project", priority: :none },
      { name: "Go outside and have some fun", priority: :none }
    ].each do |task_attrs|
      task_list.tasks.create!(
        name: task_attrs[:name],
        priority: task_attrs[:priority],
        project_id: project.id,
        user_id: id
      )
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
