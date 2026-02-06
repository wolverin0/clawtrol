class ValidationSuggestionService
  MODELS = {
    "glm" => { url: "https://api.z.ai/api/coding/paas/v4/chat/completions", model: "glm-4.7-flash" }
  }.freeze

  # File extension to test command mappings
  FILE_TYPE_COMMANDS = {
    # Ruby/Rails
    ".rb" => "bin/rails test",
    ".rake" => "bin/rails test",
    # JavaScript/TypeScript
    ".js" => "npm test",
    ".ts" => "npm test",
    ".jsx" => "npm test",
    ".tsx" => "npm test",
    # Views
    ".erb" => "bin/rails test:system",
    ".html" => "bin/rails test:system",
    ".haml" => "bin/rails test:system",
    ".slim" => "bin/rails test:system",
    # CSS/Assets
    ".css" => "bin/rails assets:precompile",
    ".scss" => "bin/rails assets:precompile",
    ".sass" => "bin/rails assets:precompile",
    # Python
    ".py" => "python -m pytest",
    # Config/YAML
    ".yml" => "bin/rails test",
    ".yaml" => "bin/rails test"
  }.freeze

  # Class method for rule-based suggestion (no AI, no user required)
  # Used by AutoValidationJob for background auto-validation
  def self.generate_rule_based(task)
    new(nil).generate_rule_based_suggestion(task)
  end

  def initialize(user)
    @user = user
  end

  def generate_suggestion(task, rule_based_only: false)
    # Skip AI if rule_based_only is true
    unless rule_based_only
      # Try AI-powered suggestion first if configured
      if configured?
        ai_suggestion = generate_ai_suggestion(task)
        return ai_suggestion if ai_suggestion.present?
      end
    end

    # Fallback to rule-based suggestion
    generate_rule_based_suggestion(task)
  end

  # Public method for rule-based suggestion (called by class method and instance)
  def generate_rule_based_suggestion(task)
    output_files = task.output_files || []
    
    return nil if output_files.empty?

    # Analyze file types
    extensions = output_files.map { |f| File.extname(f).downcase }.uniq
    
    # Check for test files first - run those directly
    test_files = output_files.select { |f| f.include?("_test.rb") || f.include?("_spec.rb") }
    if test_files.any?
      if test_files.all? { |f| f.include?("_spec.rb") }
        return "bundle exec rspec #{test_files.take(5).join(' ')}"
      else
        return "bin/rails test #{test_files.take(5).join(' ')}"
      end
    end

    # Check for system test indicators
    if extensions.include?(".erb") || output_files.any? { |f| f.include?("views/") }
      return "bin/rails test:system"
    end

    # Check for JS files
    if (extensions & [".js", ".ts", ".jsx", ".tsx"]).any?
      if extensions.include?(".rb")
        return "npm test"  # Can't chain with && due to safety rules
      end
      return "npm test"
    end

    # Default to Rails test for Ruby files
    if extensions.include?(".rb")
      # Try to find corresponding test files
      impl_files = output_files.select { |f| f.end_with?(".rb") && !f.include?("test/") && !f.include?("spec/") }
      
      if impl_files.any?
        # Generate test path guesses
        test_paths = impl_files.map do |f|
          if f.start_with?("app/")
            f.sub("app/", "test/").sub(".rb", "_test.rb")
          else
            nil
          end
        end.compact

        if test_paths.any?
          return "bin/rails test #{test_paths.take(3).join(' ')}"
        end
      end
      
      return "bin/rails test"
    end

    # Python files
    if extensions.include?(".py")
      return "python -m pytest"
    end

    # No known file types — return nil (human will review)
    nil
  end

  private

  def configured?
    @user&.ai_api_key.present?
  end

  def generate_ai_suggestion(task)
    prompt = build_prompt(task)
    call_api(prompt)
  rescue => e
    Rails.logger.error "ValidationSuggestionService AI error: #{e.message}"
    nil
  end

  def build_prompt(task)
    output_files = task.output_files || []
    file_list = output_files.take(20).join("\n") # Limit to avoid token overflow

    <<~PROMPT
      Generate a shell validation command for this completed task in a Rails project.

      Task: #{task.name}
      Description: #{task.description.to_s.truncate(500)}

      Output files:
      #{file_list.presence || "(none listed)"}

      Rules:
      - Output ONLY the shell command, no explanation
      - Command must start with one of: bin/rails, bundle exec, npm, yarn, make, pytest, rspec, ruby, node, bash bin/, sh bin/, ./bin/
      - No shell metacharacters like ;, |, &, $, backticks
      - Use && only to chain safe commands
      - For Ruby files: prefer `bin/rails test <test_files>` or `bundle exec rspec <spec_files>`
      - For JS files: prefer `npm test` or `node -c <files>`
      - For view files (.erb, .html): prefer `bin/rails test:system`
      - For mixed changes: combine relevant test commands
      - If there are specific test files in output_files, test those directly
      - Default to `bin/rails test` if uncertain

      Output only the command:
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
      messages: [{ role: "user", content: prompt }],
      max_tokens: 150,
      thinking: { type: "disabled" }
    }.to_json

    response = http.request(request)
    data = JSON.parse(response.body)
    
    command = data.dig("choices", 0, "message", "content")&.strip
    
    # Validate the command is safe
    return nil unless command.present?
    return nil if command.match?(Task::UNSAFE_COMMAND_PATTERN)
    return nil unless Task::ALLOWED_VALIDATION_PREFIXES.any? { |prefix| command.start_with?(prefix) }
    
    command
  end
end
