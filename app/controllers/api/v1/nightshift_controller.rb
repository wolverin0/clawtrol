require "open3"
require "timeout"

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
            { nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
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
            { nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).update_all(enabled: true)
        NightshiftSelection.for_tonight.where.not(nightshift_mission_id: mission_ids).update_all(enabled: false)

        armed = NightshiftSelection.for_tonight.enabled
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      # POST /api/v1/nightshift/sync_crons
      def sync_crons
        crons = fetch_nightshift_crons
        synced = 0
        selections_created = 0

        crons.each do |cron|
          # Extract mission name from "🌙 NS: Name" pattern
          raw_name = cron["name"].to_s
          mission_name = raw_name.sub(/^🌙\s*NS:\s*/, "").strip
          next if mission_name.blank?

          mission = NightshiftMission.find_or_initialize_by(name: mission_name)
          if mission.new_record?
            mission.assign_attributes(
              enabled: cron["enabled"] != false,
              frequency: "always",
              category: "general",
              icon: "🌙",
              description: "Auto-synced from OpenClaw cron: #{raw_name}",
              estimated_minutes: ((cron.dig("payload", "timeoutSeconds") || 300) / 60.0).ceil
            )
            mission.save!
          end
          synced += 1

          # Auto-create selection for tonight if mission is due
          next unless mission.enabled? && mission.due_tonight?
          next if NightshiftSelection.for_tonight.exists?(nightshift_mission_id: mission.id)

          NightshiftSelection.create!(
            nightshift_mission_id: mission.id,
            title: mission.name,
            scheduled_date: Date.current,
            enabled: true,
            status: "pending"
          )
          selections_created += 1
        end

        render json: { synced: synced, selections_created: selections_created }
      end

      # POST /api/v1/nightshift/report_execution
      def report_execution
        cron_name = params[:cron_name].to_s.sub(/^🌙\s*NS:\s*/, "").strip
        status = params[:status].to_s.presence || "completed"
        result = params[:result].to_s.presence

        mission = NightshiftMission.find_by(name: cron_name)
        unless mission
          return render json: { error: "Mission not found: #{cron_name}" }, status: :not_found
        end

        selection = NightshiftSelection.for_tonight.find_by(nightshift_mission_id: mission.id)
        unless selection
          # Auto-create selection if missing
          selection = NightshiftSelection.create!(
            nightshift_mission_id: mission.id,
            title: mission.name,
            scheduled_date: Date.current,
            enabled: true,
            status: "pending"
          )
        end

        selection.update!(
          status: status,
          result: result,
          completed_at: Time.current
        )
        mission.update!(last_run_at: Time.current)

        render json: { ok: true, selection_id: selection.id, status: selection.status }
      end

      def selections
        @selections = NightshiftSelection.for_tonight.enabled
        render json: @selections
      end

      def update_selection
        @selection = NightshiftSelection.find(params[:id])

        status = selection_params[:status]
        result = selection_params[:result]

        if status.present?
          NightshiftEngineService.new.complete_selection(@selection, status: status, result: result)
        else
          @selection.update!(selection_params)
        end

        render json: @selection.reload
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      private

      def fetch_nightshift_crons
        stdout, _stderr, status = Timeout.timeout(20) do
          Open3.capture3("openclaw", "cron", "list", "--json")
        end
        return [] unless status&.exitstatus == 0

        raw = JSON.parse(stdout)
        Array(raw["jobs"]).select { |j| j["name"].to_s.include?("🌙 NS:") }
      rescue StandardError => e
        Rails.logger.warn("[Nightshift] Failed to fetch crons: #{e.message}")
        []
      end

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
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{gateway_token}"
        )
      rescue => e
        Rails.logger.warn("[Nightshift] Failed to notify OpenClaw: #{e.message}")
      end
    end
  end
end
