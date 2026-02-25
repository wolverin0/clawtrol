# frozen_string_literal: true

class DailyExecutiveDigestJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    User.find_each do |user|
      DailyExecutiveDigestService.new(user).call
    end
  end
end
