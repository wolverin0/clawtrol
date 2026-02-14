class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.includes(task: :board).recent.limit(100)
    @unread_count = current_user.notifications.unread.count
  end

  def mark_read
    notification = current_user.notifications.includes(task: :board).find(params[:id])
    notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("notification_#{notification.id}", partial: "notifications/notification", locals: { notification: notification }) }
      format.html { redirect_to notifications_path }
    end
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "All notifications marked as read."
  end
end
