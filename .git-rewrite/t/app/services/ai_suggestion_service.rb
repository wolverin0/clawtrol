class AiSuggestionService
  MODELS = {
    "glm" => { url: "https://api.z.ai/api/coding/paas/v4/chat/completions", model: "glm-4.7-flash" }
  }.freeze

  def initialize(user)
    @user = user
  end

  def generate_followup(task)
    return fallback_suggestion(task) unless configured?

    prompt = build_followup_prompt(task)
    call_api(prompt)
  end

  def enhance_description(task, draft)
    return draft unless configured?

    prompt = build_enhance_prompt(task, draft)
    call_api(prompt)
  end

  private

  def configured?
    @user.ai_api_key.present?
  end

  def build_followup_prompt(task)
    <<~PROMPT
      Analyze this completed task and suggest specific, actionable follow-up tasks.

      Task: #{task.name}

      Output/Results:
      #{task.description}

      Based on the findings above, suggest 3-5 specific next steps. Be concrete - reference specific items found.
      Format as a markdown list.
    PROMPT
  end

  def build_enhance_prompt(task, draft)
    <<~PROMPT
      Enhance this follow-up task description with specific details from the parent task.

      Parent Task: #{task.name}
      Parent Output: #{task.description}

      User's Draft: #{draft}

      Rewrite the draft to be more specific and actionable, incorporating relevant details from the parent task output.
      Keep the same intent but add concrete details.
    PROMPT
  end

  def call_api(prompt)
    config = MODELS[@user.ai_suggestion_model] || MODELS["glm"]

    uri = URI.parse(config[:url])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@user.ai_api_key}"
    })

    request.body = {
      model: config[:model],
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 500,
      thinking: { type: "disabled" }
    }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)
    data.dig("choices", 0, "message", "content") || fallback_suggestion(nil)
  rescue => e
    Rails.logger.error "AI API error: #{e.message}"
    nil
  end

  def fallback_suggestion(task)
    "Review the task results and determine next steps."
  end
end
