class ProcessSavedLinkJob < ApplicationJob
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

    # Call Gemini
    prompt_text = "#{SYSTEM_PROMPT}\n\n---\nContent from: #{link.url}\nTitle: #{link.title}\n\n#{content}"
    summary = call_gemini(prompt_text)

    link.update!(summary: summary, status: :done, processed_at: Time.current)
  rescue => e
    link&.update(status: :failed, error_message: "#{e.class}: #{e.message}"[0..500])
    Rails.logger.error("[ProcessSavedLinkJob] Failed for link #{saved_link_id}: #{e.message}")
  end

  private

  def fetch_content(url)
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
    # Remove scripts, styles, nav, footer
    doc.css("script, style, nav, footer, header, aside, .sidebar, .menu, .nav").remove

    # Try article/main first, fall back to body
    node = doc.at_css("article") || doc.at_css("main") || doc.at_css("body")
    text = node&.text&.gsub(/\s+/, " ")&.strip || ""
    text[0...15_000]
  end

  def call_gemini(prompt_text)
    api_key = ENV.fetch("GEMINI_API_KEY")
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash:generateContent?key=#{api_key}")

    body = { contents: [ { parts: [ { text: prompt_text } ] } ] }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = body
      http.request(request)
    end

    raise "Gemini API error #{response.code}: #{response.body[0..300]}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data.dig("candidates", 0, "content", "parts", 0, "text") || raise("No text in Gemini response")
  end
end
