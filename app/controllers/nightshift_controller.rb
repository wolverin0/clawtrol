class NightshiftController < ApplicationController

  def index
    sync_service = NightshiftSyncService.new
    sync_service.sync_tonight_selections
    Rails.cache.fetch("nightshift/sync_crons", expires_in: 5.minutes) { sync_service.sync_crons; true }

    @missions = current_user.nightshift_missions.enabled.ordered
    @selections = NightshiftSelection.for_tonight.index_by(&:nightshift_mission_id)
    @due_tonight_ids = @missions.select(&:due_tonight?).map(&:id)
    @total_time = @missions.sum(&:estimated_minutes)
    @categories = NightshiftMission::CATEGORIES
    @frequencies = NightshiftMission::FREQUENCIES
  end

  def launch
    selected_ids = params[:mission_ids]&.map(&:to_i) || []
    missions = current_user.nightshift_missions.where(id: selected_ids)

    existing_selections = NightshiftSelection.for_tonight
      .where(nightshift_mission_id: selected_ids)
      .index_by(&:nightshift_mission_id)

    missions_to_create = missions.reject { |m| existing_selections[m.id] }

    new_selections = missions_to_create.map do |mission|
      {
        nightshift_mission_id: mission.id,
        title: mission.name,
        scheduled_date: Date.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    NightshiftSelection.insert_all(new_selections) if new_selections.any?

    NightshiftSelection.for_tonight.where(nightshift_mission_id: selected_ids).update_all(enabled: true)
    NightshiftSelection.for_tonight.where.not(nightshift_mission_id: selected_ids).update_all(enabled: false)

    NightshiftRunnerJob.perform_later if nightshift_hours?

    render json: { success: true, armed_count: selected_ids.count }, status: :ok
  end

  def create
    @mission = current_user.nightshift_missions.new(mission_params)
    if @mission.save
      redirect_to nightshift_path, notice: "Mission created"
    else
      redirect_to nightshift_path, alert: @mission.errors.full_messages.join(", ")
    end
  end

  def update
    @mission = current_user.nightshift_missions.find(params[:id])
    if @mission.update(mission_params)
      redirect_to nightshift_path, notice: "Mission updated"
    else
      redirect_to nightshift_path, alert: @mission.errors.full_messages.join(", ")
    end
  end

  def destroy
    @mission = current_user.nightshift_missions.find(params[:id])
    @mission.destroy
    redirect_to nightshift_path, notice: "Mission deleted"
  end

  private

  def mission_params
    params.require(:nightshift_mission).permit(
      :name, :description, :icon, :model, :estimated_minutes,
      :frequency, :enabled, :created_by, :category, :position,
      days_of_week: []
    )
  end

  def nightshift_hours?
    hour = Time.current.hour
    hour >= 23 || hour < 8
  end
end
