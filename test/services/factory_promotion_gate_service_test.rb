# frozen_string_literal: true

require "test_helper"

class FactoryPromotionGateServiceTest < ActiveSupport::TestCase
  test "verify! runs syntax and test checks" do
    check = FactoryPromotionGateService::Result.new(name: "ok", success: true, output: "pass")

    FactoryPromotionGateService.stub(:run_check, check) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s)

      assert result[:success]
      assert_equal "Promotion gate passed", result[:message]
      assert_equal 2, result[:checks].size
      assert_equal ["ok", "ok"], result[:checks].map { |c| c[:name] }
    end
  end

  test "verify! fails when any check fails" do
    passing = FactoryPromotionGateService::Result.new(name: "syntax_check", success: true, output: "ok")
    failing = FactoryPromotionGateService::Result.new(name: "test_command", success: false, output: "boom")

    calls = 0
    FactoryPromotionGateService.stub(:run_check, lambda { |**_kwargs|
      calls += 1
      calls == 1 ? passing : failing
    }) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s)

      assert_not result[:success]
      assert_equal "Promotion gate failed", result[:message]
      assert_equal [true, false], result[:checks].map { |c| c[:success] }
    end
  end

  test "verify! includes e2e check when requested" do
    check = FactoryPromotionGateService::Result.new(name: "ok", success: true, output: "pass")

    FactoryPromotionGateService.stub(:run_check, check) do
      result = FactoryPromotionGateService.verify!(Rails.root.to_s, include_e2e: true)
      assert_equal 3, result[:checks].size
    end
  end
end
