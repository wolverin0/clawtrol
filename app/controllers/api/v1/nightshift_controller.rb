# frozen_string_literal: true

module Api
  module V1
    class NightshiftController < BaseController
      # Cron-facing endpoints use hook token auth instead of Bearer
      skip_before_action :authenticate_api_token, only: [:report_execution, :sync_crons, :sync_tonight]
      before_action :authenticate_hook_token, only: [:report_execution, :sync_crons, :sync_tonight]

      # GET /api/v1/nightshift/missions
      def missions
        missions = current_user.nightshift_missions.enabled.ordered
        render json: missions.map(&:to_mission_hash)
      end

      # POST /api/v1/nightshift/missions
      def create_mission
        mission = current_user.nightshift_missions.new(mission_params)
        if mission.save
          render json: mission.to_mission_hash, status: :created
        else
          render json: { errors: mission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/nightshift/missions/:id
      def update_mission
        mission = current_user.nightshift_missions.find(params[:id])
        if mission.update(mission_params)
          render json: mission.to_mission_hash
        else
          render json: { errors: mission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/nightshift/missions/:id
      def destroy_mission
        mission = current_user.nightshift_missions.find(params[:id])
        mission.destroy
        render json: { success: true }
      end

      # GET /api/v1/nightshift/tonight
      def tonight
        missions = current_user.nightshift_missions.enabled.ordered
        due = missions.select(&:due_tonight?)
        # SECURITY: scope selections to current user's missions only
        user_mission_ids = current_user.nightshift_missions.pluck(:id)
        selections = NightshiftSelection.for_tonight.enabled
          .where(nightshift_mission_id: user_mission_ids)

        render json: {
          due_missions: due.map(&:to_mission_hash),
          selections: selections,
          date: Date.current.iso8601
        }
      end

      # POST /api/v1/nightshift/tonight/approve
      def approve_tonight
        # SECURITY: scope all operations to current user's missions only
        user_mission_ids = current_user.nightshift_missions.pluck(:id)
        mission_ids = params[:mission_ids]&.map(&:to_i) || current_user.nightshift_missions.enabled.select(&:due_tonight?).map(&:id)
        # Ensure requested mission_ids belong to current user
        mission_ids = mission_ids & user_mission_ids
        missions = current_user.nightshift_missions.where(id: mission_ids)

        existing = NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).index_by(&:nightshift_mission_id)
        new_records = missions.reject { |m| existing[m.id] }

        if new_records.any?
          NightshiftSelection.insert_all(new_records.map { |m|
            { nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        # SECURITY: only update selections belonging to current user's missions
        NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).update_all(enabled: true)
        NightshiftSelection.for_tonight
          .where(nightshift_mission_id: user_mission_ids)
          .where.not(nightshift_mission_id: mission_ids)
          .update_all(enabled: false)
        # NOTE: Do NOT set last_run_at here - missions haven't run yet.
        # last_run_at is set by NightshiftEngineService#complete_selection on actual completion.

        armed = NightshiftSelection.for_tonight.enabled
          .where(nightshift_mission_id: user_mission_ids)
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      def sync_tonight
        created = NightshiftSyncService.new.sync_tonight_selections
        due_count = NightshiftMission.enabled.select(&:due_tonight?).size
        render json: { synced: due_count, created: created, date: Date.current.iso8601 }
      end

      # Legacy endpoints for backward compat
      def tasks
        missions = current_user.nightshift_missions.enabled.ordered
        render json: missions.map(&:to_mission_hash)
      end

      def launch
        task_ids = params[:task_ids] || []
        tasks = current_user.tasks.where(id: task_ids)
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
        # SECURITY: scope all operations to current user's missions only
        user_mission_ids = current_user.nightshift_missions.pluck(:id)
        mission_ids = (params[:mission_ids] || []).map(&:to_i)
        # Ensure requested mission_ids belong to current user
        mission_ids = mission_ids & user_mission_ids
        missions = current_user.nightshift_missions.where(id: mission_ids)

        existing = NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).index_by(&:nightshift_mission_id)
        new_records = missions.reject { |m| existing[m.id] }

        if new_records.any?
          NightshiftSelection.insert_all(new_records.map { |m|
            { nightshift_mission_id: m.id, title: m.name, scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        NightshiftSelection.for_tonight.where(nightshift_mission_id: mission_ids).update_all(enabled: true)
        # SECURITY: only disable selections for current user's missions, not all users'
        NightshiftSelection.for_tonight
          .where(nightshift_mission_id: user_mission_ids)
          .where.not(nightshift_mission_id: mission_ids)
          .update_all(enabled: false)

        armed = NightshiftSelection.for_tonight.enabled
          .where(nightshift_mission_id: user_mission_ids)
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      # POST /api/v1/nightshift/sync_crons
      def sync_crons
        result = NightshiftSyncService.new.sync_crons
        render json: result
      end

      # POST /api/v1/nightshift/report_execution
      # NOTE: uses hook token auth (service-to-service), not user auth
      def report_execution
        mission_name = params[:mission_name].to_s.strip
        if mission_name.blank? || mission_name.length > 255
          return render json: { error: "invalid mission_name" }, status: :bad_request
        end

        mission = NightshiftMission.find_by(name: mission_name)
        unless mission
          return render json: { error: "mission not found" }, status: :not_found
        end

        # Validate status param against allowed values
        status = params[:status].to_s
        unless NightshiftSelection::STATUSES.include?(status)
          return render json: { error: "invalid status, must be one of: #{NightshiftSelection::STATUSES.join(', ')}" }, status: :bad_request
        end

        # Truncate result to prevent oversized payloads
        result = params[:result].to_s.truncate(50_000) if params[:result].present?

        selection = NightshiftSelection.find_or_create_by!(
          nightshift_mission_id: mission.id,
          scheduled_date: Date.current
        ) do |sel|
          sel.title = mission.name
          sel.enabled = true
          sel.status = "pending"
        end

        NightshiftEngineService.new.complete_selection(
          selection,
          status: status,
          result: result
        )

        render json: selection.reload
      end

      def selections
        user_mission_ids = current_user.nightshift_missions.pluck(:id)
        @selections = NightshiftSelection.for_tonight.enabled
          .where(nightshift_mission_id: user_mission_ids)
        render json: @selections
      end

      def update_selection
        @selection = NightshiftSelection
          .joins(:nightshift_mission)
          .where(nightshift_missions: { user_id: current_user.id })
          .find(params[:id])

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

      def authenticate_hook_token
        token = request.headers["X-Hook-Token"].to_s
        configured_token = Rails.application.config.hooks_token.to_s
        unless configured_token.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured_token)
          render json: { error: "unauthorized" }, status: :unauthorized
        end
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
      rescue StandardError => e
        Rails.logger.warn("[Nightshift] Failed to notify OpenClaw: #{e.message}")
      end
    end
  end
end
