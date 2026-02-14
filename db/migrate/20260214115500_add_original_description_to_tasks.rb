class AddOriginalDescriptionToTasks < ActiveRecord::Migration[8.1]
  def up
    add_column :tasks, :original_description, :text

    # Backfill existing tasks
    Task.where(original_description: nil).find_each do |t|
      desc = t.description.to_s
      if desc.include?("\n\n---\n\n")
        _top, rest = desc.split("\n\n---\n\n", 2)
        t.update_column(:original_description, rest)
      elsif !desc.start_with?("## Agent Activity") && !desc.start_with?("## Agent Output")
        t.update_column(:original_description, desc) if desc.present?
      end
    end
  end

  def down
    remove_column :tasks, :original_description
  end
end
