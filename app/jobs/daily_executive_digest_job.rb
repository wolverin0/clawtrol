# frozen_string_literal: true

class DailyExecutiveDigestJob < ApplicationJob
  queue_as :default

  def perform
    DailyExecutiveDigestService.call
  end
end
