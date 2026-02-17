# frozen_string_literal: true

class FactoryStackDetector
  def self.call(workspace_path)
    new(workspace_path).call
  end

  def initialize(workspace_path)
    @workspace_path = workspace_path.to_s
  end

  def call
    return fallback_stack unless Dir.exist?(@workspace_path)

    if file?("Gemfile") && file?("config/application.rb")
      rails_stack
    elsif file?("next.config.js") || file?("next.config.mjs")
      nextjs_stack
    elsif file?("vite.config.js") || file?("vite.config.ts")
      vite_stack
    elsif file?("package.json")
      node_stack
    elsif file?("requirements.txt") || file?("pyproject.toml")
      python_stack
    else
      fallback_stack
    end
  end

  private

  def file?(name)
    File.exist?(File.join(@workspace_path, name))
  end

  def rails_stack
    {
      framework: "rails",
      language: "ruby",
      test_command: "bin/rails test",
      syntax_check: "ruby -c"
    }
  end

  def nextjs_stack
    {
      framework: "nextjs",
      language: "javascript",
      test_command: "npm test",
      syntax_check: "node -c"
    }
  end

  def vite_stack
    {
      framework: "vite",
      language: "javascript",
      test_command: "npm test",
      syntax_check: "node -c"
    }
  end

  def node_stack
    {
      framework: "node",
      language: "javascript",
      test_command: "npm test",
      syntax_check: "node -c"
    }
  end

  def python_stack
    {
      framework: "python",
      language: "python",
      test_command: "pytest",
      syntax_check: "python -m py_compile"
    }
  end

  def fallback_stack
    {
      framework: "unknown",
      language: "unknown",
      test_command: "true",
      syntax_check: "true"
    }
  end
end
