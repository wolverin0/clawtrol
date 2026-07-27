# frozen_string_literal: true

module Api
  module V1
    class OrchestrationController < BaseController
      before_action -> { require_api_scope!("orchestration_bridge:sync") }

      def sync
        result = Orchestration::SyncIngestor.new(current_user).sync(sync_payload)
        render json: {
          server_time: Time.current.iso8601,
          source: source_json(result.source),
          accepted: result.accepted,
          intents: result.intents
        }
      rescue Orchestration::InvalidRequest => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def sync_payload
        request.request_parameters.slice(
          "profile",
          "generated_at",
          "health",
          "panes",
          "tasks",
          "events",
          "messages",
          "intent_results"
        )
      end

      def source_json(source)
        {
          id: source.id,
          profile: source.profile,
          status: source.display_status,
          last_seen_at: source.last_seen_at&.iso8601
        }
      end
    end
  end
end
