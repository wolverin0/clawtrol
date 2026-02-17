# frozen_string_literal: true

class FactoryStackDetector
  def self.call(workspace_path)
    new(workspace_path).call
  end

  def initialize(workspace_path)
    @workspace_path = workspace_path.to_s
  end

  def call
    return unknown_stack unless Dir.exist?(@workspace_path)

    return rails_stack if rails?
    return next_stack if nextjs?
    return node_stack if node?
    return python_stack if python?

    unknown_stack
  end

  private

  def rails?
    file?("Gemfile") && file?("config/application.rb")
  end

  def nextjs?
    file?("next.config.js") || file?("next.config.mjs") || file?("next.config.ts")
  end

  def node?
    file?("package.json")
  end

  def python?
    file?("pyproject.toml") || file?("requirements.txt")
  end

  def file?(path)
    File.exist?(File.join(@workspace_path, path))
  end

  def rails_stack
    {
      framework: "rails",
      language: "ruby",
      test_command: "bin/rails test",
      syntax_check: "git diff --name-only -- '*.rb' | xargs -r ruby -c"
    }
  end

  def next_stack
    {
      framework: "nextjs",
      language: "javascript",
      test_command: "npm test -- --watch=false",
      syntax_check: "git diff --name-only -- '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' | xargs -r node --check"
    }
  end

  def node_stack
    {
      framework: "node",
      language: "javascript",
      test_command: "npm test",
      syntax_check: "git diff --name-only -- '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' | xargs -r node --check"
    }
  end

  def python_stack
    {
      framework: "python",
      language: "python",
      test_command: "pytest",
      syntax_check: "python -m py_compile $(git diff --name-only -- '*.py')"
    }
  end

  def unknown_stack
    {
      framework: "unknown",
      language: "unknown",
      test_command: "true",
      syntax_check: "true"
    }
  end
end
