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
      assert_includes result[:syntax_check], "ruby -c"
    end
  end

  test "detects node stack" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "package.json"), "{}")

      result = FactoryStackDetector.call(dir)

      assert_equal "node", result[:framework]
      assert_equal "javascript", result[:language]
      assert_equal "npm test", result[:test_command]
      assert_includes result[:syntax_check], "node --check"
    end
  end

  test "returns fallback when unknown" do
    Dir.mktmpdir do |dir|
      result = FactoryStackDetector.call(dir)

      assert_equal "unknown", result[:framework]
      assert_equal "true", result[:test_command]
      assert_equal "true", result[:syntax_check]
    end
  end
end
