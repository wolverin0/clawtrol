# frozen_string_literal: true

# LobsterRunner — Executes Lobster workflow pipelines via OpenClaw Gateway.
#
# Lobster is OpenClaw's deterministic pipeline runner with resumeToken support
# for approval gates (pausing mid-pipeline until a human approves/rejects).
#
# Usage:
#   LobsterRunner.run("code-review", { "task_id" => "42" })
#   LobsterRunner.resume(token, approve: true)
class LobsterRunner
  LOBSTER_DIR = Rails.root.join("lobster")

  def self.run(pipeline_name, args = {})
    pipeline_path = LOBSTER_DIR.join("#{pipeline_name}.lobster")
    raise ArgumentError, "Pipeline not found: #{pipeline_name}" unless pipeline_path.exist?

    client = OpenclawGatewayClient.new(nil)
    client.invoke_tool!("lobster", args: {
      action: "run",
      pipeline: pipeline_path.to_s,
      args: args,
      timeoutMs: 60_000
    })
  rescue OpenclawGatewayClient::Error => e
    Rails.logger.error("[LobsterRunner] run failed: #{e.message}")
    { "error" => e.message }
  rescue ArgumentError => e
    { "error" => e.message }
  end

  def self.resume(token, approve: true)
    raise ArgumentError, "Token is required" if token.blank?

    client = OpenclawGatewayClient.new(nil)
    client.invoke_tool!("lobster", args: {
      action: "resume",
      token: token,
      approve: approve
    })
  rescue OpenclawGatewayClient::Error => e
    Rails.logger.error("[LobsterRunner] resume failed: #{e.message}")
    { "error" => e.message }
  end

  def self.available_pipelines
    return [] unless LOBSTER_DIR.exist?

    LOBSTER_DIR.glob("*.lobster").map { |f| f.basename(".lobster").to_s }.sort
  end
end
