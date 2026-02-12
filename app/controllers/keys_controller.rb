class KeysController < ApplicationController
  before_action :require_admin

  ENV_FILE = File.expand_path("~/.openclaw/.env").freeze

  PROVIDERS = [
    { key: "OPENAI_API_KEY", label: "OpenAI (GPT/Codex)", placeholder: "sk-proj-..." },
    { key: "ANTHROPIC_API_KEY", label: "Claude (Anthropic)", placeholder: "sk-ant-..." },
    { key: "ZHIPU_API_KEY", label: "GLM (Z.AI)", placeholder: "" },
    { key: "GEMINI_API_KEY", label: "Gemini (Google)", placeholder: "AIza..." },
    { key: "OPENROUTER_API_KEY", label: "OpenRouter", placeholder: "sk-or-..." },
    { key: "MINIMAX_API_KEY", label: "MiniMax", placeholder: "" },
    { key: "MEMU_API_KEY", label: "memU", placeholder: "" },
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

    params[:keys]&.each do |env_key, value|
      next if value.blank?
      next unless PROVIDERS.any? { |p| p[:key] == env_key }

      # Replace or append
      found = false
      lines.map! do |line|
        if line.strip.start_with?("#{env_key}=")
          found = true
          "#{env_key}=#{value}\n"
        else
          line
        end
      end
      lines << "#{env_key}=#{value}\n" unless found
      updated_keys << env_key
    end

    File.write(ENV_FILE, lines.join)
    File.chmod(0600, ENV_FILE)

    redirect_to keys_path, notice: "✅ Updated #{updated_keys.size} key(s): #{updated_keys.join(', ')}"
  end

  private

  def require_admin
    redirect_to root_path, alert: "Not authorized" unless current_user&.admin?
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
