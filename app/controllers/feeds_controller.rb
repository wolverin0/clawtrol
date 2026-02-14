# frozen_string_literal: true

class FeedsController < ApplicationController
  def index
    @feed_names = current_user.feed_entries.distinct.pluck(:feed_name).sort
    base = current_user.feed_entries

    # Filters
    base = base.by_feed(params[:feed]) if params[:feed].present?
    base = base.where(status: params[:status]) if params[:status].present? && FeedEntry.statuses.key?(params[:status])
    base = base.high_relevance if params[:relevance] == "high"

    @pagy, @feed_entries = pagy(base.newest_first, items: 30)

    # Stats — single query with PostgreSQL FILTER clauses instead of 5 separate COUNTs
    today_start = Time.current.beginning_of_day
    stats_row = current_user.feed_entries.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{FeedEntry.statuses['unread']})"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{FeedEntry.statuses['saved']})"),
      Arel.sql("COUNT(*) FILTER (WHERE created_at >= #{ActiveRecord::Base.connection.quote(today_start)})"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{FeedEntry.statuses['unread']} AND relevance_score >= 0.7)")
    )
    @stats = {
      total: stats_row[0] || 0,
      unread: stats_row[1] || 0,
      saved: stats_row[2] || 0,
      today: stats_row[3] || 0,
      high_relevance: stats_row[4] || 0,
      feeds: @feed_names.size
    }
  end

  def show
    @feed_entry = current_user.feed_entries.find(params[:id])
    @feed_entry.update(status: :read, read_at: Time.current) if @feed_entry.unread?
  end

  def update
    @feed_entry = current_user.feed_entries.find(params[:id])
    if @feed_entry.update(feed_entry_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@feed_entry) }
        format.html { redirect_to feeds_path }
      end
    else
      redirect_to feeds_path, alert: @feed_entry.errors.full_messages.join(", ")
    end
  end

  def mark_read
    current_user.feed_entries.unread.update_all(status: :read, read_at: Time.current)
    redirect_to feeds_path, notice: "All entries marked as read."
  end

  def dismiss
    @feed_entry = current_user.feed_entries.find(params[:id])
    @feed_entry.update!(status: :dismissed)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@feed_entry) }
      format.html { redirect_to feeds_path }
    end
  end

  def destroy
    @feed_entry = current_user.feed_entries.find(params[:id])
    @feed_entry.destroy
    redirect_to feeds_path, notice: "Entry deleted."
  end

  private

  def feed_entry_params
    params.expect(feed_entry: [:status])
  end
end
