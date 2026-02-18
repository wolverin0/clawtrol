# frozen_string_literal: true

class BoardRoadmapTaskLink < ApplicationRecord
  belongs_to :board_roadmap, inverse_of: :task_links
  belongs_to :task

  validates :item_key, presence: true, uniqueness: { scope: :board_roadmap_id }
  validates :item_text, presence: true
  validates :task_id, uniqueness: { scope: :board_roadmap_id }
end
