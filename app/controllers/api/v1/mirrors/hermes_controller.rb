# frozen_string_literal: true

module Api
  module V1
    module Mirrors
      class HermesController < BaseController
        before_action -> { require_api_scope!("hermes_mirror:write") }

        def sessions
          result = ingestor.upsert_session(mirror_params(:brief, :title, :board_id))
          render json: session_json(result), status: result.created ? :created : :ok
        rescue HermesMirror::InvalidRequest => e
          render_invalid_request(e)
        end

        def events
          result = ingestor.append_events(event_params)
          render json: {
            task_id: result.task.id,
            run_id: result.task_run.run_id,
            created: result.created_count,
            duplicates: result.duplicate_count
          }
        rescue HermesMirror::InvalidRequest => e
          render_invalid_request(e)
        end

        def completions
          result = ingestor.complete_session(
            mirror_params(:terminal_state, :outcome, :ended_at)
          )
          render json: completion_json(result)
        rescue HermesMirror::InvalidRequest => e
          render_invalid_request(e)
        end

        private

        def ingestor
          @ingestor ||= HermesMirror::Ingestor.new(current_user)
        end

        def mirror_params(*fields)
          params.permit(:profile, :session_id, *fields).to_h.symbolize_keys
        end

        def event_params
          permitted = params.permit(
            :profile,
            :session_id,
            events: [:seq, :timestamp, :event_type, :level, :message, { payload: {} }]
          )
          permitted.to_h.deep_symbolize_keys
        end

        def session_json(result)
          {
            task_id: result.task.id,
            run_id: result.task_run.run_id,
            external_source_key: result.task_run.external_source_key,
            origin_session_key: result.task.origin_session_key,
            created: result.created
          }
        end

        def completion_json(result)
          {
            task_id: result.task.id,
            run_id: result.task_run.run_id,
            terminal_state: result.task_run.raw_payload["mirror_terminal_state"],
            idempotent: result.idempotent
          }
        end

        def render_invalid_request(exception)
          render json: { error: exception.message }, status: :unprocessable_entity
        end
      end
    end
  end
end
