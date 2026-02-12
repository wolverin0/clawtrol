module Api
  module V1
    class NightshiftController < BaseController
      # GET /api/v1/nightshift/tasks — list all nightly-eligible tasks
      def tasks
        tasks = Task.where(nightly: true).where.not(status: [:archived, :done])
        render json: tasks.map { |t|
          {
            id: t.id,
            name: t.name,
            model: t.model,
            nightly_delay_hours: t.nightly_delay_hours,
            status: t.status
          }
        }
      end

      # POST /api/v1/nightshift/launch — receive selected task IDs, mark them for tonight's run
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

        render json: {
          success: true,
          launched: launched.size,
          tasks: launched,
          message: "Nightshift armed with #{launched.size} missions"
        }
      end

      # POST /api/v1/nightshift/arm - persist mission selections for tonight
      def arm
        mission_ids = (params[:mission_ids] || []).map(&:to_i)
        
        # Load mission catalog
        missions = ::NightshiftController::MISSIONS
        selected = missions.select { |m| mission_ids.include?(m[:id]) }

        existing = NightshiftSelection.for_tonight.where(mission_id: mission_ids).index_by(&:mission_id)
        new_records = selected.reject { |m| existing[m[:id]] }

        if new_records.any?
          NightshiftSelection.insert_all(new_records.map { |m|
            { mission_id: m[:id], title: m[:title], scheduled_date: Date.current,
              enabled: true, status: "pending", created_at: Time.current, updated_at: Time.current }
          })
        end

        NightshiftSelection.for_tonight.where(mission_id: mission_ids).update_all(enabled: true)
        NightshiftSelection.for_tonight.where.not(mission_id: mission_ids).update_all(enabled: false)

        armed = NightshiftSelection.for_tonight.enabled
        render json: { success: true, armed_count: armed.count, selections: armed }
      end

      # GET /api/v1/nightshift/selections - returns tonight's enabled selections
      def selections
        @selections = NightshiftSelection.for_tonight.enabled
        render json: @selections
      end

      # PATCH /api/v1/nightshift/selections/:id - for agents to report back
      def update_selection
        @selection = NightshiftSelection.find(params[:id])
        if @selection.update(selection_params)
          render json: @selection
        else
          render json: { errors: @selection.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      private

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
