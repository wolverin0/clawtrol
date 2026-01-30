class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :api_tokens, dependent: :destroy
  has_one :inbox_project, -> { where(inbox: true) }, class_name: "Project"
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validate :acceptable_avatar, if: :avatar_changed?

  after_commit :send_admin_notification, on: :create
  after_create :create_inbox
  after_create :create_welcome_project

  validates :email_address, presence: true,
                           uniqueness: { case_sensitive: false },
                           format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  # Generate a 6-digit verification code that expires in 15 minutes
  def generate_verification_code
    self.verification_code = rand(100000..999999).to_s
    self.code_expires_at = 15.minutes.from_now
    save!
  end

  # Verify the code is correct and not expired
  def verify_code(code)
    return false if verification_code.blank? || code_expires_at.blank?
    return false if Time.current > code_expires_at

    verification_code == code
  end

  # Clear verification code after successful login
  def clear_verification_code
    update(verification_code: nil, code_expires_at: nil)
  end

  # Get or create the user's inbox project
  def inbox
    inbox_project || create_inbox
  end

  private

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
