# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FactoryStackDetectorTest < ActiveSupport::TestCase
  test "detects rails stack" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'")
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config", "application.rb"), "module App; end")

      result = FactoryStackDetector.call(dir)

      assert_equal "rails", result[:framework]
      assert_equal "ruby", result[:language]
      assert_equal "bin/rails test", result[:test_command]
    end
  end

  test "detects python stack" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "requirements.txt"), "pytest")

      result = FactoryStackDetector.call(dir)

      assert_equal "python", result[:framework]
      assert_equal "python", result[:language]
      assert_equal "pytest", result[:test_command]
    end
  end

  test "returns fallback when unknown" do
    Dir.mktmpdir do |dir|
      result = FactoryStackDetector.call(dir)

      assert_equal "unknown", result[:framework]
      assert_equal "true", result[:test_command]
    end
  end
end
