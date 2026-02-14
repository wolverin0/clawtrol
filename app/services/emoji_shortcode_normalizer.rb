# frozen_string_literal: true

class EmojiShortcodeNormalizer
  SHORTCODE_MAP = {
    "pager" => "📟"
  }.freeze

  def self.normalize(value)
    raw = value.to_s.strip
    return raw if raw.blank?

    if raw.match?(/\A:[a-z0-9_+\-]+:\z/i)
      key = raw.delete_prefix(":").delete_suffix(":").downcase
      return SHORTCODE_MAP[key] || raw
    end

    raw
  end
end
