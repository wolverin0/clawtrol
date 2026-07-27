# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    SafeLan::LegacyExecutionPolicy.enforce_job!(job.class.name)
    block.call
  end

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
