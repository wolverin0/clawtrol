# frozen_string_literal: true

require "test_helper"

class SubAgentOutputContractTest < ActiveSupport::TestCase
  test "from_params returns nil when no contract data is provided" do
    assert_nil SubAgentOutputContract.from_params({})
    assert_nil SubAgentOutputContract.from_params({ "foo" => "bar" })
  end

  test "normalize extracts nested output_contract and normalizes list fields" do
    payload = {
      "output_contract" => {
        "summary" => "  Added promotion gate checks  ",
        "changes" => [" one ", "", "two"],
        "follow_up" => "line one\n\n line two ",
        "recommended_action" => "  promote  "
      }
    }

    normalized = SubAgentOutputContract.normalize(payload)

    assert_equal "Added promotion gate checks", normalized["summary"]
    assert_equal ["one", "two"], normalized["changes"]
    assert_equal ["line one", "line two"], normalized["follow_up"]
    assert_equal "promote", normalized["recommended_action"]
  end

  test "validation keeps hash payloads, trims scalar text, and omits blank validation" do
    contract_with_hash = SubAgentOutputContract.new({ "validation" => { "tests" => "pass", "syntax" => "pass" } })
    assert_equal({ "tests" => "pass", "syntax" => "pass" }, contract_with_hash.to_payload["validation"])

    contract_with_text = SubAgentOutputContract.new({ "validation" => "  all green  " })
    assert_equal "all green", contract_with_text.to_payload["validation"]

    contract_with_blank_text = SubAgentOutputContract.new({ "validation" => "   " })
    refute_includes contract_with_blank_text.to_payload.keys, "validation"
  end

  test "to_markdown renders all populated sections" do
    contract = SubAgentOutputContract.new(
      "summary" => "Refined scanner",
      "changes" => ["Added health checks", "Improved logs"],
      "validation" => { "bin/rails test" => "ok" },
      "follow_up" => ["Ship after review"],
      "recommended_action" => "Promote"
    )

    markdown = contract.to_markdown

    assert_includes markdown, "### Summary\nRefined scanner"
    assert_includes markdown, "### Changes\n- Added health checks\n- Improved logs"
    assert_includes markdown, "### Validation\n- bin/rails test: ok"
    assert_includes markdown, "### Follow-up\n- Ship after review"
    assert_includes markdown, "### Recommended Action\nPromote"
  end
end
