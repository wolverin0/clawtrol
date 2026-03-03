# frozen_string_literal: true

class Boards::FileRefsController < ApplicationController
  before_action :set_board
  before_action :set_file_ref, only: [:destroy]

  def create
    @file_ref = @board.file_refs.new(file_ref_params)

    if @file_ref.save
      redirect_to board_path(@board), notice: "File reference added."
    else
      redirect_to board_path(@board), alert: @file_ref.errors.full_messages.to_sentence
    end
  end

  def destroy
    @file_ref.destroy
    redirect_to board_path(@board), notice: "File reference removed."
  end

  private

  def set_board
    @board = current_user.boards.find(params[:board_id])
  end

  def set_file_ref
    @file_ref = @board.file_refs.find(params[:id])
  end

  def file_ref_params
    params.require(:board_file_ref).permit(:path, :label, :category, :position)
  end
end
