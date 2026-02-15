# frozen_string_literal: true

class ProcessSavedLinkJob < ApplicationJob
  include SsrfProtection
  queue_as :default

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are ClawTrol's Link Analyst. Evaluate this content for relevance to:
    1. ClawTrol — Rails 8 task management, Hotwire/Stimulus patterns, agent orchestration, kanban UIs
    2. OpenClaw — AI agent gateway, plugin systems, LLM orchestration, CLI tools

    Produce a report with:
    - **Summary** (2-3 sentences of what this content is about)
    - **ClawTrol Relevance** (High/Medium/Low/None + specific ideas)
    - **OpenClaw Relevance** (High/Medium/Low/None + specific ideas)
    - **Action Items** (concrete integration ideas, or "None — not relevant")

    Be concise but specific. If it's a YouTube video, analyze based on title/description.
  PROMPT

  def perform(saved_link_id)
    link = SavedLink.find(saved_link_id)
    link.update!(status: :processing)

    # Fetch content
    content = fetch_content(link.url)
    link.update!(raw_content: content)

    # Call Gemini via CLI (uses OAuth, no API key needed)
    prompt_text = "#{SYSTEM_PROMPT}\n\n---\nContent from: #{link.url}\nNote: #{link.note}\n\n#{content}"
    summary = call_gemini_cli(prompt_text)

    link.update!(summary: summary, status: :done, processed_at: Time.current)
  rescue StandardError => e
    link&.update(status: :failed, error_message: "#{e.class}: #{e.message}"[0..500])
    Rails.logger.error("[ProcessSavedLinkJob] Failed for link #{saved_link_id}: #{e.message}")
  end

  private

  def fetch_content(url)
    # SECURITY: Prevent SSRF — block fetching from internal/private network hosts
    unless safe_outbound_url?(url)
      raise "Blocked: URL points to private/internal network address"
    end

    # X/Twitter: use fxtwitter API for tweet content
    if url.match?(%r{(x\.com|twitter\.com)/.+/status/(\d+)})
      return fetch_tweet(url)
    end

    uri = URI.parse(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 15) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; ClawDeck/1.0)"
      http.request(request)
    end

    # Follow redirects (one level)
    if response.is_a?(Net::HTTPRedirection) && response["location"]
      uri = URI.parse(response["location"])
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Mozilla/5.0 (compatible; ClawDeck/1.0)"
        http.request(request)
      end
    end

    doc = Nokogiri::HTML(response.body)
    doc.css("script, style, nav, footer, header, aside, .sidebar, .menu, .nav").remove

    node = doc.at_css("article") || doc.at_css("main") || doc.at_css("body")
    text = node&.text&.gsub(/\s+/, " ")&.strip || ""
    text[0...15_000]
  end

  def fetch_tweet(url)
    # Extract status ID and build fxtwitter API URL
    status_id = url[/status\/(\d+)/, 1]
    return "(Could not extract tweet ID from URL)" unless status_id

    api_url = URI("https://api.fxtwitter.com/i/status/#{status_id}")
    response = Net::HTTP.start(api_url.host, api_url.port, use_ssl: true, open_timeout: 10, read_timeout: 15) do |http|
      http.request(Net::HTTP::Get.new(api_url))
    end

    return "(fxtwitter API error: #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    tweet = data.dig("tweet") || {}

    parts = []
    parts << "Author: #{tweet.dig('author', 'name')} (@#{tweet.dig('author', 'screen_name')})"
    parts << "Text: #{tweet['text']}" if tweet["text"].present?
    parts << "Likes: #{tweet['likes']}, Retweets: #{tweet['retweets']}, Replies: #{tweet['replies']}"

    if (quote = tweet["quote"])
      parts << "Quoted tweet by @#{quote.dig('author', 'screen_name')}: #{quote['text']}"
    end

    if (media = tweet.dig("media", "all"))
      media.each_with_index do |m, i|
        parts << "Media #{i + 1}: #{m['type']}#{" - #{m['altText']}" if m['altText'].present?}"
      end
    end

    result = parts.join("\n")
    result.presence || "(Tweet content is empty — may have been deleted or is media-only)"
  end

  def call_gemini_cli(prompt_text)
    # Write prompt to temp file to avoid shell escaping issues
    tmpfile = Rails.root.join("tmp", "gemini_prompt_#{SecureRandom.hex(8)}.txt")
    File.write(tmpfile, prompt_text)

    begin
      # Use gemini CLI with OAuth (model: gemini-3-flash)
      output = `cat #{tmpfile.to_s.shellescape} | gemini -m gemini-3-flash-preview 2>/dev/null`
      raise "Gemini CLI failed (exit #{$?.exitstatus}): #{output[0..300]}" unless $?.success?
      raise "Empty response from Gemini CLI" if output.strip.empty?
      output.strip
    ensure
      File.delete(tmpfile) if File.exist?(tmpfile)
    end
  end
end
