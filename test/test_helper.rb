# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["HOOKS_TOKEN"] ||= "test_hooks_token"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# Ensure hooks_token is set in config (matches ENV, survives parallel forks)
Rails.application.config.hooks_token = ENV.fetch("HOOKS_TOKEN", "test_hooks_token")

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
