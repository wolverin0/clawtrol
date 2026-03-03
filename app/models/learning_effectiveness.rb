# frozen_string_literal: true

class LearningEffectiveness < ApplicationRecord
  self.table_name = "learning_effectiveness"

  belongs_to :task
  belongs_to :task_run, optional: true

  validates :learning_entry_id, :learning_title, :surfaced_at, presence: true

  scope :for_learning, ->(entry_id) { where(learning_entry_id: entry_id) }
  scope :succeeded, -> { where(task_succeeded: true) }
  scope :failed, -> { where(task_succeeded: false) }
  scope :recent, ->(days = 30) { where("created_at >= ?", days.days.ago) }
  scope :with_scores, -> { where.not(effectiveness_score: nil) }

  def self.success_rate_for(entry_id)
    records = for_learning(entry_id)
    return nil if records.none?

    records.succeeded.count.to_f / records.count
  end

  def self.aggregated_stats
    select(
      "learning_entry_id",
      "learning_title",
      "COUNT(*) AS total_surfaced",
      "SUM(CASE WHEN task_succeeded THEN 1 ELSE 0 END) AS success_count",
      "MAX(surfaced_at) AS last_surfaced_at",
      "AVG(effectiveness_score) AS avg_effectiveness"
    ).group(:learning_entry_id, :learning_title)
  end
end
