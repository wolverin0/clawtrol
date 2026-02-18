# frozen_string_literal: true

module Boards
  class RoadmapsController < ApplicationController
    before_action :set_board

    def update
      roadmap = @board.roadmap || @board.build_roadmap
      roadmap.assign_attributes(roadmap_params)

      if roadmap.save
        redirect_to board_path(@board), notice: "Roadmap saved."
      else
        redirect_to board_path(@board), alert: roadmap.errors.full_messages.join(", ")
      end
    end

    def generate_tasks
      roadmap = @board.roadmap

      if roadmap.blank?
        redirect_to board_path(@board), alert: "Add a roadmap first."
        return
      end

      result = BoardRoadmapTaskGenerator.new(roadmap).call
      redirect_to board_path(@board), notice: "Generated #{result.created_count} task(s) from roadmap."
    end

    private

    def set_board
      @board = current_user.boards.find(params[:board_id])
    end

    def roadmap_params
      params.require(:board_roadmap).permit(:body)
    end
  end
end
