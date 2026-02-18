# frozen_string_literal: true

class QuickAddController < ApplicationController
  before_action :require_authentication

  # GET /quick_add
  def new
    @boards = current_user.boards.includes(:user).order(:name)
    @default_board = @boards.first
  end

  # POST /quick_add
  def create
    permitted = params.permit(:board_id, :name, :description, tags: [])
    board = current_user.boards.find_by(id: permitted[:board_id]) || current_user.boards.first
    return redirect_to quick_add_path, alert: "No board found" unless board

    name = permitted[:name].to_s.strip
    return redirect_to quick_add_path, alert: "Title is required" if name.blank?

    # Truncate inputs to sane limits
    name = name.truncate(500)
    description = permitted[:description].to_s.strip.truncate(10_000).presence

    text_for_tagging = [name, description].compact.join(" ")
    tags = AutoTaggerService.tag(text_for_tagging)
    tags += Array(permitted[:tags]).map { |t| t.to_s.strip.truncate(100) }.reject(&:blank?) if permitted[:tags].present?
    tags = tags.uniq.first(10)

    task = board.tasks.new(
      name: name,
      description: description,
      status: :inbox,
      user: current_user,
      tags: tags,
      model: AutoTaggerService.suggest_model(tags)
    )

    if task.save
      redirect_to quick_add_path, notice: "✅ Task ##{task.id} created"
    else
      redirect_to quick_add_path, alert: "Failed: #{task.errors.full_messages.join(', ')}"
    end
  end
end
