# frozen_string_literal: true

module IdentityLinksHelper
  CHANNEL_ICON_MAP = {
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

  def channel_icon_for(channel)
    CHANNEL_ICON_MAP[channel.to_s.downcase] || "📡"
  end
end
