# frozen_string_literal: true

module AgentConfigHelper
  CHANNEL_ICONS = {
    "telegram" => "📱",
    "discord" => "🎮",
    "whatsapp" => "💬",
    "signal" => "🔒",
    "slack" => "💼",
    "irc" => "📺",
    "matrix" => "🟢",
    "imessage" => "🍎",
    "googlechat" => "🔵"
  }.freeze

  def channel_icon(channel_key)
    # Try to match known channel names from the key
    key_lower = channel_key.to_s.downcase
    CHANNEL_ICONS.each do |name, icon|
      return icon if key_lower.include?(name)
    end
    "📡" # default
  end
end
