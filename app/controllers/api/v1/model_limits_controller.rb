module Api
  module V1
    class ModelLimitsController < BaseController
      # GET /api/v1/models/status - get status of all models for current user
      def status
        # Clear any expired limits first
        ModelLimit.clear_expired_limits!

        # Build status for each model
        statuses = Task::MODELS.map do |model|
          limit = current_user.model_limits.find_by(name: model)

          if limit&.active_limit?
            {
              model: model,
              available: false,
              limited: true,
              resets_at: limit.resets_at&.iso8601,
              resets_in: limit.time_until_reset,
              error_message: limit.error_message,
              last_error_at: limit.last_error_at&.iso8601
            }
          else
            {
              model: model,
              available: true,
              limited: false,
              resets_at: nil,
              resets_in: nil,
              error_message: nil,
              last_error_at: nil
            }
          end
        end

        # Include the priority order for reference
        render json: {
          models: statuses,
          priority_order: ModelLimit::MODEL_PRIORITY,
          fallback_chain: current_user.fallback_model_chain&.split(",") || ModelLimit::MODEL_PRIORITY
        }
      end

      # POST /api/v1/models/:model_name/limit - record a rate limit
      # Can pass resets_at explicitly or it will be parsed from error_message
      def record_limit
        model_name = params[:model_name]

        unless Task::MODELS.include?(model_name)
          render json: { error: "Invalid model: #{model_name}" }, status: :unprocessable_entity
          return
        end

        error_message = params[:error_message] || "Rate limit exceeded"

        # Use ModelLimit.record_limit! which parses reset time from error message
        limit = ModelLimit.record_limit!(current_user, model_name, error_message)

        # Override with explicit resets_at if provided
        if params[:resets_at].present?
          limit.update!(resets_at: Time.parse(params[:resets_at]))
        end

        render json: {
          model: model_name,
          limited: true,
          resets_at: limit.resets_at&.iso8601,
          resets_in: limit.time_until_reset,
          message: "Rate limit recorded for #{model_name}"
        }
      end

      # DELETE /api/v1/models/:model_name/limit - clear a rate limit
      def clear_limit
        model_name = params[:model_name]

        unless Task::MODELS.include?(model_name)
          render json: { error: "Invalid model: #{model_name}" }, status: :unprocessable_entity
          return
        end

        limit = current_user.model_limits.find_by(name: model_name)
        limit&.clear!

        render json: {
          model: model_name,
          limited: false,
          message: "Rate limit cleared for #{model_name}"
        }
      end

      # POST /api/v1/models/best - get best available model with fallback
      def best
        requested_model = params[:requested_model]

        if requested_model.present? && !Task::MODELS.include?(requested_model)
          render json: { error: "Invalid model: #{requested_model}" }, status: :unprocessable_entity
          return
        end

        model, fallback_note = ModelLimit.best_available_model(current_user, requested_model)

        render json: {
          model: model,
          requested: requested_model,
          fallback_used: fallback_note.present?,
          fallback_note: fallback_note
        }
      end
    end
  end
end
