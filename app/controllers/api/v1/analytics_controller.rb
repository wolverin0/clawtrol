module Api
  module V1
    class AnalyticsController < BaseController
      # GET /api/v1/analytics/tokens?period=week
      def tokens
        period = params[:period] || "week"
        start_date = case period
                     when "today" then Time.current.beginning_of_day
                     when "week" then 1.week.ago
                     when "month" then 1.month.ago
                     when "all" then 1.year.ago
                     else 1.week.ago
                     end

        usages = TokenUsage.for_user(current_user).by_date_range(start_date)

        # Apply optional filters
        usages = usages.by_model(params[:model]) if params[:model].present?
        usages = usages.by_board(params[:board_id]) if params[:board_id].present?

        render json: {
          period: period,
          start_date: start_date.iso8601,
          summary: {
            total_input_tokens: usages.total_input,
            total_output_tokens: usages.total_output,
            total_tokens: usages.total_tokens_count,
            total_cost: usages.total_cost.to_f.round(6)
          },
          by_model: format_model_breakdown(usages),
          daily: format_daily_usage(usages, start_date),
          by_board: format_board_breakdown(usages)
        }
      end

      private

      def format_model_breakdown(usages)
        usages.tokens_by_model.map do |row|
          {
            model: row.model,
            input_tokens: row.total_input.to_i,
            output_tokens: row.total_output.to_i,
            total_tokens: row.total_input.to_i + row.total_output.to_i,
            cost: row.total_cost.to_f.round(6),
            usage_count: row.usage_count
          }
        end.sort_by { |r| -r[:cost] }
      end

      def format_daily_usage(usages, start_date)
        daily = usages.daily_usage(start_date)
        daily.map do |row|
          {
            date: row.date.to_s,
            input_tokens: row.total_input.to_i,
            output_tokens: row.total_output.to_i,
            cost: row.total_cost.to_f.round(6),
            usage_count: row.usage_count
          }
        end
      end

      def format_board_breakdown(usages)
        usages.by_board_breakdown.map do |row|
          {
            board_id: row.board_id,
            board_name: row.board_name,
            board_icon: row.board_icon,
            input_tokens: row.total_input.to_i,
            output_tokens: row.total_output.to_i,
            cost: row.total_cost.to_f.round(6),
            usage_count: row.usage_count
          }
        end
      end
    end
  end
end
