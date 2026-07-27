#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.expand_path("..", __dir__)
forbidden_files = %w[
  app/services/agent_platforms/hermes_adapter.rb
  app/services/agent_platforms/hermes_cli_runner.rb
].freeze
scan_roots = %w[
  app/controllers
  app/jobs
  app/services
  app/views
  config
].freeze
scan_files = scan_roots.flat_map { |path| Dir.glob(File.join(root, path, "**", "*.{rb,erb,js}")) }
scan_files << File.join(root, "script", "hermes_clawtrol_logger.py")

patterns = {
  /HermesAdapter|HermesCliRunner/ => "direct Hermes adapter or CLI runner",
  /\bhermes_(?:gateway_(?:url|token)|hooks_token|home)\b/ => "direct-control Hermes setting",
  /["'](?:hermes_only|dual)["']/ => "direct-control orchestration mode",
  /HERMES_GATEWAY_(?:URL|TOKEN)/ => "Hermes gateway environment credential"
}.freeze

violations = forbidden_files.filter_map do |relative_path|
  "#{relative_path}: forbidden direct-control file exists" if File.exist?(File.join(root, relative_path))
end

scan_files.select! { |path| File.file?(path) }
scan_files.each do |path|
  relative_path = path.delete_prefix("#{root}/").tr("\\", "/")
  source = File.read(path)
  patterns.each do |pattern, description|
    violations << "#{relative_path}: #{description}" if source.match?(pattern)
  end
  if relative_path == "script/hermes_clawtrol_logger.py" && source.match?(%r{\.openclaw[/\\]\.env})
    violations << "#{relative_path}: OpenClaw environment fallback"
  end
end

if violations.any?
  warn "Passive Hermes boundary gate failed:"
  violations.uniq.sort.each { |violation| warn "- #{violation}" }
  exit 1
end

puts "Passive Hermes boundary gate passed."
