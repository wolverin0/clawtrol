# frozen_string_literal: true

class KeysController < ApplicationController
  # Auth handled by ApplicationController (requires login)

  ENV_FILE = File.expand_path("~/.openclaw/.env").freeze

  PROVIDERS = [
    { key: "OPENAI_API_KEY", label: "OpenAI (GPT/Codex)", placeholder: "sk-proj-..." },
    { key: "ANTHROPIC_API_KEY", label: "Claude (Anthropic)", placeholder: "sk-ant-..." },
    { key: "ZHIPU_API_KEY", label: "GLM (Z.AI)", placeholder: "" },
    { key: "GEMINI_API_KEY", label: "Gemini (Google)", placeholder: "AIza..." },
    { key: "OPENROUTER_API_KEY", label: "OpenRouter", placeholder: "sk-or-..." },
    { key: "MINIMAX_API_KEY", label: "MiniMax", placeholder: "" },
    { key: "MEMU_API_KEY", label: "memU", placeholder: "" }
  ].freeze

  def index
    @providers = PROVIDERS.map do |p|
      current = read_env_value(p[:key])
      p.merge(
        current: current,
        masked: current.present? ? mask_key(current) : nil
      )
    end
  end

  def update
    lines = File.exist?(ENV_FILE) ? File.readlines(ENV_FILE) : []
    updated_keys = []
    rejected_keys = []

    params[:keys]&.each do |env_key, value|
      next if value.blank?
      next unless PROVIDERS.any? { |p| p[:key] == env_key }

      # SECURITY: Sanitize API key values before writing to .env file
      sanitized = sanitize_env_value(value)
      unless sanitized
        rejected_keys << env_key
        next
      end

      # Replace or append
      found = false
      lines.map! do |line|
        if line.strip.start_with?("#{env_key}=")
          found = true
          "#{env_key}=#{sanitized}\n"
        else
          line
        end
      end
      lines << "#{env_key}=#{sanitized}\n" unless found
      updated_keys << env_key
    end

    File.write(ENV_FILE, lines.join)
    File.chmod(0600, ENV_FILE)

    notice = "✅ Updated #{updated_keys.size} key(s): #{updated_keys.join(', ')}"
    notice += " ⚠️ Rejected #{rejected_keys.size} invalid key(s): #{rejected_keys.join(', ')}" if rejected_keys.any?
    redirect_to keys_path, notice: notice
  end

  private

  # SECURITY: Sanitize values written to .env to prevent:
  # 1. Newline injection (injecting arbitrary env vars via \n, \r)
  # 2. Shell metachar injection (backticks, $(), ; when file is sourced)
  # 3. Null byte injection
  # API keys are alphanumeric + dashes/underscores/dots/colons — reject anything else.
  def sanitize_env_value(value)
    val = value.to_s.strip

    # Reject null bytes
    return nil if val.include?("\x00")

    # Reject newlines (primary injection vector: \n, \r, \r\n)
    return nil if val.match?(/[\r\n]/)

    # Reject shell-dangerous characters that could execute commands
    # when the .env file is sourced via `source` or `.`
    # Backtick, $(), ;, |, &, >, <, and embedded quotes
    return nil if val.match?(/[`$;|&><"'\\]/)

    # Reject empty after strip
    return nil if val.empty?

    # Reject unreasonably long values (API keys are typically 40-200 chars)
    return nil if val.length > 500

    val
  end

  def read_env_value(key)
    return nil unless File.exist?(ENV_FILE)
    File.readlines(ENV_FILE).each do |line|
      if line.strip =~ /\A#{Regexp.escape(key)}=(.+)\z/
        return $1.strip
      end
    end
    nil
  end

  def mask_key(value)
    return value if value.length <= 8
    "#{value[0..3]}#{'•' * [value.length - 8, 4].max}#{value[-4..]}"
  end
end
