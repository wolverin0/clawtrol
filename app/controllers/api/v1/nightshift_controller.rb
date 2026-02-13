module Api
  module V1
    class NightshiftController < BaseController
      # GET /api/v1/nightshift/missions
      def missions
        missions = NightshiftMission.enabled.ordered
        render json: missions.map(&:to_mission_hash)
      end

      # POST /api/v1/nightshift/missions
      def create_mission
        mission = NightshiftMission.new(mission_params)
        if mission.save
          render json: mission.to_mission_hash, status: :created
        else
          render json: { errors: mission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/nightshift/missions/:id
      def update_mission
        mission = NightshiftMission.find(params[:id])
        if mission.update(mission_params)
          render json: mission.to_mission_hash
        else
          render json: { errors: mission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/nightshift/missions/:id
      def destroy_mission
        mission = NightshiftMission.find(params[:id])
        mission.destroy
        render json: { success: true }
      end

      # GET /api/v1/nightshift/tonight
      def tonight
        missions = NightshiftMission.enabled.ordered
        due = missions.select(&:due_tonight?)
        selections = NightshiftSelection.for_tonight.enabled

        render json: {
          due_missions: due.map(&:to_mission_hash),
          selections: selections,
          date: Date.current.iso8601
        }
      end

      # POST /api/v1/nightshift/tonight/approve
      def approve_tonight
        mission_ids = params[:mission_ids]&.map(&:to_i) || NightshiftMission.enabled.select(&:due_tonight?).map(&:id)
        missions = NightshiftMission.where(id: mission_ids)

        existing = NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).index_by(&:nightshift_mission_id)
        new_records = missions.reject { |m| existing[m.id] }

        if new_records.any?
          NightshiftSelection.insert_all(new_records.map { |m|
            { mission_id: m.id, nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).update_all(enabled: true)
        NightshiftSelection.for_tonight.where.not(nightshift_mission_id: mission_ids).update_all(enabled: false)
        NightshiftMission.where(id: mission_ids).update_all(last_run_at: Time.current)

        armed = NightshiftSelection.for_tonight.enabled
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      # Legacy endpoints for backward compat
      def tasks
        missions = NightshiftMission.enabled.ordered
        render json: missions.map(&:to_mission_hash)
      end

      def launch
        task_ids = params[:task_ids] || []
        tasks = Task.where(id: task_ids)
        launched = []

        tasks.each do |task|
          task.update(status: :up_next, assigned_to_agent: true) if task.status_before_type_cast < 2
          launched << { id: task.id, name: task.name, status: task.status }
        end

        if launched.any?
          notify_openclaw("🌙 Nightshift launched with #{launched.size} tasks: #{launched.map { |t| t[:name] }.join(', ')}")
        end

        render json: { success: true, launched: launched.size, tasks: launched }
      end

      def arm
        mission_ids = (params[:mission_ids] || []).map(&:to_i)
        missions = NightshiftMission.where(id: mission_ids)

        existing = NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).index_by(&:nightshift_mission_id)
        new_records = missions.reject { |m| existing[m.id] }

        if new_records.any?
          NightshiftSelection.insert_all(new_records.map { |m|
            { mission_id: m.id, nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).update_all(enabled: true)
        NightshiftSelection.for_tonight.where.not(nightshift_mission_id: mission_ids).update_all(enabled: false)

        armed = NightshiftSelection.for_tonight.enabled
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      def selections
        @selections = NightshiftSelection.for_tonight.enabled
        render json: @selections
      end

      def update_selection
        @selection = NightshiftSelection.find(params[:id])
        if @selection.update(selection_params)
          render json: @selection
        else
          render json: { errors: @selection.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def mission_params
        params.permit(
          :name, :description, :icon, :model, :estimated_minutes,
          :frequency, :enabled, :created_by, :category, :position,
          days_of_week: []
        )
      end

      def selection_params
        params.permit(:status, :result, :launched_at, :completed_at)
      end

      def notify_openclaw(message)
        gateway_url = Rails.application.config.respond_to?(:openclaw_gateway_url) ? Rails.application.config.openclaw_gateway_url : nil
        gateway_token = Rails.application.config.respond_to?(:openclaw_gateway_token) ? Rails.application.config.openclaw_gateway_token : nil
        return unless gateway_url && gateway_token

        uri = URI("#{gateway_url}/api/sessions/main/message")
        Net::HTTP.post(uri, { message: message }.to_json,
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{gateway_token}"
        )
      rescue => e
        Rails.logger.warn("[Nightshift] Failed to notify OpenClaw: #{e.message}")
      end
    end
  end
end
