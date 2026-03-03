# frozen_string_literal: true

module ValidationCommandSafety
  extend ActiveSupport::Concern

  private

  def validation_command_is_safe
    cmd = validation_command.to_s.strip

    if cmd.match?(validation_command_unsafe_pattern)
      errors.add(:validation_command, validation_command_unsafe_message)
      return
    end

    unless validation_command_allowed_prefixes.any? { |prefix| cmd.start_with?(prefix) }
      errors.add(:validation_command, validation_command_prefix_message)
    end
  end

  def validation_command_unsafe_pattern
    Task::UNSAFE_COMMAND_PATTERN
  end

  def validation_command_allowed_prefixes
    Task::ALLOWED_VALIDATION_PREFIXES
  end

  def validation_command_unsafe_message
    "contains unsafe shell metacharacters"
  end

  def validation_command_prefix_message
    "must start with an allowed prefix"
  end
end
