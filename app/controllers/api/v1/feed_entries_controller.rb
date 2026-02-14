# frozen_string_literal: true

module Api
  module V1
    class FeedEntriesController < BaseController
      # POST /api/v1/feed_entries — n8n pushes entries here
      # Accepts single entry or batch: { entries: [...] }
      def create
        if params[:entries].present?
          batch_create
        else
          single_create
        end
      end

      # GET /api/v1/feed_entries
      def index
        entries = current_user.feed_entries.newest_first
        entries = entries.by_feed(params[:feed]) if params[:feed].present?
        entries = entries.where(status: params[:status]) if params[:status].present?
        entries = entries.high_relevance if params[:relevance] == "high"
        entries = entries.recent(params[:days].to_i) if params[:days].present?
        entries = entries.limit(params[:limit]&.to_i || 50)
        render json: entries
      end

      # GET /api/v1/feed_entries/stats
      # Consolidated into 2 queries (down from 7):
      #   1. Single SELECT with conditional COUNTs
      #   2. GROUP BY feed_name for breakdown
      def stats
        today_start = Time.current.beginning_of_day
        counts = current_user.feed_entries
          .pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(*) FILTER (WHERE status = 0)"),           # unread
            Arel.sql("COUNT(*) FILTER (WHERE status = 2)"),           # saved
            Arel.sql("COUNT(*) FILTER (WHERE created_at >= #{ActiveRecord::Base.connection.quote(today_start)})"),
            Arel.sql("COUNT(*) FILTER (WHERE relevance_score >= 0.7)")
          )
        by_feed = current_user.feed_entries.group(:feed_name).count

        render json: {
          total: counts[0],
          unread: counts[1],
          saved: counts[2],
          today: counts[3],
          high_relevance: counts[4],
          feeds: by_feed.keys,
          by_feed: by_feed
        }
      end

      # PATCH /api/v1/feed_entries/:id
      def update
        entry = current_user.feed_entries.find(params[:id])
        if entry.update(update_params)
          render json: entry
        else
          render json: { error: entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def single_create
        entry = current_user.feed_entries.build(entry_params)
        if entry.save
          render json: entry, status: :created
        else
          render json: { error: entry.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def batch_create
        results = { created: 0, skipped: 0, errors: [] }
        entries = params[:entries]

        unless entries.is_a?(Array) && entries.size <= 100
          return render json: { error: "entries must be an array with max 100 items" }, status: :unprocessable_entity
        end

        entries.each_with_index do |entry_data, idx|
          entry = current_user.feed_entries.build(
            feed_name: entry_data[:feed_name],
            feed_url: entry_data[:feed_url],
            title: entry_data[:title],
            url: entry_data[:url],
            author: entry_data[:author],
            summary: entry_data[:summary],
            content: entry_data[:content],
            relevance_score: entry_data[:relevance_score],
            tags: entry_data[:tags],
            published_at: entry_data[:published_at]
          )
          if entry.save
            results[:created] += 1
          else
            if entry.errors[:url]&.include?("has already been taken")
              results[:skipped] += 1
            else
              results[:errors] << { index: idx, errors: entry.errors.full_messages }
            end
          end
        end

        render json: results, status: :created
      end

      def entry_params
        params.permit(:feed_name, :feed_url, :title, :url, :author, :summary,
                       :content, :relevance_score, :published_at, tags: [])
      end

      def update_params
        params.permit(:status, :relevance_score, :summary, tags: [])
      end
    end
  end
end
