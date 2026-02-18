# frozen_string_literal: true

class BoardRoadmap < ApplicationRecord
  CHECKLIST_REGEX = /^\s*-\s\[\s\]\s+(.+?)\s*$/.freeze

  belongs_to :board
  has_many :task_links, class_name: "BoardRoadmapTaskLink", dependent: :destroy, inverse_of: :board_roadmap

  validates :body, length: { maximum: 500_000 }

  def unchecked_items
    body.to_s.each_line.filter_map do |line|
      match = line.match(CHECKLIST_REGEX)
      next unless match

      text = match[1].to_s.strip
      next if text.blank?

      { text: text, key: item_key_for(text) }
    end.uniq { |item| item[:key] }
  end

  def item_key_for(text)
    normalized = text.to_s.strip.downcase.gsub(/\s+/, " ")
    Digest::SHA256.hexdigest(normalized)
  end
end
