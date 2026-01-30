class Comment < ApplicationRecord
  belongs_to :task, counter_cache: true

  validates :body, presence: true
  validates :author_type, presence: true, inclusion: { in: %w[user agent] }
  validates :author_name, presence: true

  default_scope { order(created_at: :asc) }
end
