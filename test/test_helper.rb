# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["CLAWTROL_TEST_HOOKS_TOKEN"] ||= "test_hooks_token"
ENV["CLAWTROL_TEST_LEGACY_EXECUTION"] ||= "1"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)
require_relative "test_helpers/session_test_helper"

# Historical hook tests use a test-only credential. Production has no hook token.
Rails.application.config.hooks_token = ENV.fetch("CLAWTROL_TEST_HOOKS_TOKEN", "test_hooks_token")

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
