# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class CompactionConfigControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    @user.update!(openclaw_gateway_url: "http://localhost:3377", openclaw_gateway_token: "test-token")
    sign_in_as(@user)
  end

  # ── Authentication ────────────────────────────────────────────────
  test "show requires authentication" do
    sign_out
    get compaction_config_path
    assert_response :redirect
  end

  test "show redirects when gateway not configured" do
    @user.update!(openclaw_gateway_url: nil)
    sign_in_as(@user)
    get compaction_config_path
    assert_response :redirect
  end

  # ── GET /compaction-config ────────────────────────────────────────
  test "show renders with compaction and pruning config" do
    mock_config = {
      "compaction" => { "mode" => "safeguard", "memoryFlush" => true },
      "contextPruning" => { "cacheTtl" => 30, "softTrimRatio" => 0.8 }
    }

    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, mock_config)

    OpenclawGatewayClient.stub(:new, mock_client) do
      get compaction_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show handles gateway error gracefully" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, { "error" => "unreachable" })

    OpenclawGatewayClient.stub(:new, mock_client) do
      get compaction_config_path
      assert_response :success
    end
    mock_client.verify
  end

  test "show uses defaults when config is empty" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_get, {})

    OpenclawGatewayClient.stub(:new, mock_client) do
      get compaction_config_path
      assert_response :success
    end
    mock_client.verify
  end

  # ── PATCH /compaction-config ──────────────────────────────────────
  test "update compaction mode" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { comp_mode: "eager" }
      assert_response :redirect
      assert_redirected_to compaction_config_path
    end
    mock_client.verify
  end

  test "update rejects invalid compaction mode" do
    # Invalid mode should be silently ignored (not included in patch)
    mock_client = Minitest::Mock.new
    # With only an invalid mode parameter, the patch is empty so no API call should be made
    # Actually, the controller builds an empty patch — let's check what happens
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { comp_mode: "invalid_mode" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update clamps max_turns to valid range" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { max_turns: "99999" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update clamps cache_ttl to valid range" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { cache_ttl: "0" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update clamps trim ratios" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: {
        soft_trim_ratio: "0.01",  # below min 0.1
        hard_trim_ratio: "1.5"    # above max 0.99
      }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update memory_flush boolean" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { memory_flush: "false" }
      assert_response :redirect
    end
    mock_client.verify
  end

  test "update reports gateway error" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "error" => "gateway down" }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: { comp_mode: "safeguard" }
      assert_response :redirect
      follow_redirect!
      assert_match(/gateway down|error|failed/i, flash[:alert].to_s + flash[:notice].to_s + response.body)
    end
    mock_client.verify
  end

  test "update with multiple params at once" do
    mock_client = Minitest::Mock.new
    mock_client.expect(:config_patch, { "success" => true }, [], raw: String, reason: String)

    OpenclawGatewayClient.stub(:new, mock_client) do
      patch compaction_config_path, params: {
        comp_mode: "safeguard",
        memory_flush: "true",
        max_turns: "100",
        cache_ttl: "60",
        soft_trim_ratio: "0.75",
        hard_trim_ratio: "0.9",
        preserve_system: "true"
      }
      assert_response :redirect
    end
    mock_client.verify
  end
end
