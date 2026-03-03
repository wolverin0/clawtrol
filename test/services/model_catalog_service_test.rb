require "test_helper"

class ModelCatalogServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(openclaw_gateway_url: "http://gateway.test", openclaw_gateway_token: "token")
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "returns normalized catalog from gateway and user sources" do
    tasks(:one).update!(model: "claude-3-7")
    @user.agent_personas.create!(name: "Persona #{SecureRandom.hex(4)}", model: "gpt-4.1")
    @user.model_limits.create!(name: "gemini-2.5-pro")
    @user.update!(fallback_model_chain: "custom-z\nclaude-3-7 > custom-a")

    gateway_payload = {
      "models" => {
        "providers" => {
          "openai" => { "models" => { "o3" => {}, "gpt-4.1" => {} } }
        }
      }
    }

    fake_client_class = Class.new do
      define_method(:initialize) { |_user| }
      define_method(:models_list) { gateway_payload }
    end

    catalog = ModelCatalogService.new(@user, cache: @cache, gateway_client_class: fake_client_class).model_ids

    assert_includes(catalog, "o3")
    assert_includes(catalog, "gpt-4.1")
    assert_includes(catalog, "claude-3-7")
    assert_includes(catalog, "gemini-2.5-pro")
    assert_includes(catalog, "custom-a")
    assert_includes(catalog, "custom-z")
    assert_equal(catalog.uniq, catalog)
  end

  test "returns fallback catalog when gateway client raises" do
    tasks(:one).update!(model: "fallback-model")

    failing_client = Class.new do
      define_method(:initialize) { |_user| }
      define_method(:models_list) { raise StandardError, "boom" }
    end

    catalog = ModelCatalogService.new(@user, cache: @cache, gateway_client_class: failing_client).model_ids

    assert_includes(catalog, "fallback-model")
    assert_includes(catalog, Task::MODELS.first)
  end

  test "uses task defaults when user is blank" do
    catalog = ModelCatalogService.new(nil, cache: @cache).model_ids

    assert_equal(Task::MODELS, catalog)
  end
end
