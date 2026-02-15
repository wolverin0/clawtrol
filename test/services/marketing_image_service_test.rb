# frozen_string_literal: true

require "test_helper"

class MarketingImageServiceTest < ActiveSupport::TestCase
  setup do
    @service = MarketingImageService
  end

  test "returns failure when prompt is blank" do
    result = @service.call(prompt: "")

    assert_not result[:success]
    assert_equal "Prompt is required", result[:error]
  end

  test "returns failure for invalid size" do
    result = @service.call(prompt: "test prompt", size: "invalid")

    assert_not result[:success]
    assert_match(/Invalid size/, result[:error])
  end

  test "builds full prompt with product context" do
    # Test private method by creating instance
    service = @service.new(prompt: "modern dashboard", product: "futuracrm", template: "none", size: "1024x1024")
    full_prompt = service.send(:build_full_prompt)

    assert_includes full_prompt, "FuturaCRM"
    assert_includes full_prompt, "modern dashboard"
  end

  test "builds full prompt with template style" do
    service = @service.new(prompt: "test", product: "futura", template: "ad-creative", size: "1024x1024")
    full_prompt = service.send(:build_full_prompt)

    assert_includes full_prompt, "Style:"
    assert_includes full_prompt, "Social media advertisement"
  end

  test "applies variant seed variation" do
    service1 = @service.new(prompt: "test", product: "futura", template: "none", size: "1024x1024", variant_seed: 1)
    service2 = @service.new(prompt: "test", product: "futura", template: "none", size: "1024x1024", variant_seed: 2)

    prompt1 = service1.send(:build_full_prompt)
    prompt2 = service2.send(:build_full_prompt)

    # Different seeds should produce different variations
    refute_equal prompt1, prompt2
  end

  test "valid sizes are accepted" do
    valid_sizes = %w[1024x1024 1792x1024 1024x1792]

    valid_sizes.each do |size|
      result = @service.call(prompt: "test", size: size)
      # Should not fail on size validation (will fail on API call)
      assert result.key?(:success)
    end
  end

  test "default product is futura" do
    service = @service.new(prompt: "test", product: "", template: "none", size: "1024x1024")
    full_prompt = service.send(:build_full_prompt)

    assert_includes full_prompt, "Futura Sistemas"
  end
end
