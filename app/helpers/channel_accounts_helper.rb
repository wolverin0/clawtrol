# frozen_string_literal: true

module ChannelAccountsHelper
  DM_POLICY_DESCRIPTIONS = {
    "open" => "Anyone can message",
    "pairing" => "Requires pairing code",
    "allowlist" => "Only allowed IDs",
    "disabled" => "No DMs accepted"
  }.freeze

  def dm_policy_description(policy)
    DM_POLICY_DESCRIPTIONS[policy.to_s] || "Unknown"
  end
end
