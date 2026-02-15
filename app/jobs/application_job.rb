# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Retry on transient network/connection errors (webhook calls, gateway API, etc.)
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
           Errno::ECONNRESET, Errno::EHOSTUNREACH,
           wait: :polynomially_longer, attempts: 3

  private

  def app_base_url
    Rails.application.config.app_base_url.chomp("/")
  end
end
