# frozen_string_literal: true

class AddReviewFieldsToFactoryFindingPatterns < ActiveRecord::Migration[8.0]
  def change
    add_column :factory_finding_patterns, :accepted, :boolean, default: false, null: false
    add_column :factory_finding_patterns, :accepted_at, :datetime
    add_column :factory_finding_patterns, :dismissed_at, :datetime
  end
end
