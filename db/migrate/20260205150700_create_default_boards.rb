# frozen_string_literal: true

class CreateDefaultBoards < ActiveRecord::Migration[8.1]
  def up
    # Create default boards for each existing user
    User.find_each do |user|
      # Skip if user already has these boards
      existing_names = user.boards.pluck(:name)

      # Create ClawDeck board if not exists
      unless existing_names.include?('ClawDeck')
        user.boards.create!(
          name: 'ClawDeck',
          icon: '🦞',
          color: 'rose',
          position: 1
        )
      end

      # Create Pedrito board if not exists
      unless existing_names.include?('Pedrito')
        user.boards.create!(
          name: 'Pedrito',
          icon: '🐕',
          color: 'amber',
          position: 2
        )
      end

      # Create Misc board if not exists
      unless existing_names.include?('Misc')
        user.boards.create!(
          name: 'Misc',
          icon: '📋',
          color: 'gray',
          position: 3
        )
      end
    end
  end

  def down
    # Remove the default boards (be careful - this deletes tasks!)
    Board.where(name: ['ClawDeck', 'Pedrito', 'Misc']).destroy_all
  end
end
