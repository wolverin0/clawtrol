# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "noreply@clawdeck.so"
  layout "mailer"
end
