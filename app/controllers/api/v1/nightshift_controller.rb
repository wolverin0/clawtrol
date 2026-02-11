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

      private

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
