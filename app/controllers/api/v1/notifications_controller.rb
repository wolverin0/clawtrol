module Api
  module V1
    class NotificationsController < BaseController
      before_action :set_notification, only: [:mark_read]

      # GET /api/v1/notifications
      # Returns recent notifications for current user
      # Params:
      #   - limit: max number of notifications (default: 20, max: 50)
      #   - unread_only: if true, only return unread notifications
      def index
        limit = [params[:limit].to_i, 50].min
        limit = 20 if limit <= 0

        @notifications = current_user.notifications.recent.limit(limit)
        @notifications = @notifications.unread if ActiveModel::Type::Boolean.new.cast(params[:unread_only])

        unread_count = current_user.notifications.unread.count

        render json: {
          notifications: @notifications.map { |n| notification_json(n) },
          unread_count: unread_count,
          total: current_user.notifications.count
        }
      end

      # POST /api/v1/notifications/:id/mark_read
      def mark_read
        @notification.mark_as_read!
        render json: {
          notification: notification_json(@notification),
          unread_count: current_user.notifications.unread.count
        }
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        current_user.notifications.unread.update_all(read_at: Time.current)
        render json: {
          success: true,
          unread_count: 0
        }
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end

      def notification_json(notification)
        {
          id: notification.id,
          event_type: notification.event_type,
          message: notification.message,
          icon: notification.icon,
          color_class: notification.color_class,
          read: notification.read?,
          read_at: notification.read_at&.iso8601,
          task_id: notification.task_id,
          task_name: notification.task&.name,
          board_id: notification.task&.board_id,
          created_at: notification.created_at.iso8601,
          time_ago: time_ago_in_words(notification.created_at)
        }
      end

      def time_ago_in_words(time)
        seconds = (Time.current - time).to_i
        case seconds
        when 0..59 then "just now"
        when 60..3599 then "#{seconds / 60}m ago"
        when 3600..86399 then "#{seconds / 3600}h ago"
        when 86400..604799 then "#{seconds / 86400}d ago"
        else time.strftime("%b %d")
        end
      end
    end
  end
end
