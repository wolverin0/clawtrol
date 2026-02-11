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

    # Call Gemini via CLI (uses OAuth, no API key needed)
    prompt_text = "#{SYSTEM_PROMPT}\n\n---\nContent from: #{link.url}\nTitle: #{link.title}\n\n#{content}"
    summary = call_gemini_cli(prompt_text)

    link.update!(summary: summary, status: :done, processed_at: Time.current)
  rescue StandardError => e
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
    doc.css("script, style, nav, footer, header, aside, .sidebar, .menu, .nav").remove

    node = doc.at_css("article") || doc.at_css("main") || doc.at_css("body")
    text = node&.text&.gsub(/\s+/, " ")&.strip || ""
    text[0...15_000]
  end

  def call_gemini_cli(prompt_text)
    # Write prompt to temp file to avoid shell escaping issues
    tmpfile = Rails.root.join("tmp", "gemini_prompt_#{SecureRandom.hex(8)}.txt")
    File.write(tmpfile, prompt_text)

    begin
      # Use gemini CLI with OAuth (model: gemini-3-flash)
      output = `cat #{tmpfile.to_s.shellescape} | gemini -m gemini-2.5-flash 2>/dev/null`
      raise "Gemini CLI failed (exit #{$?.exitstatus}): #{output[0..300]}" unless $?.success?
      raise "Empty response from Gemini CLI" if output.strip.empty?
      output.strip
    ensure
      File.delete(tmpfile) if File.exist?(tmpfile)
    end
  end
end
