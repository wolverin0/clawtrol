#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

root = File.expand_path("..", __dir__)
base = ENV.fetch("MIGRATION_BASE_SHA", ARGV[0].to_s)
abort "MIGRATION_BASE_SHA (or the first argument) is required" if base.empty?

changed_output, status = Open3.capture2(
  "git", "-C", root, "diff", "--name-only", "--diff-filter=AM", "#{base}...HEAD", "--", "db/migrate"
)
abort "unable to calculate migrations changed since #{base}" unless status.success?

destructive_patterns = {
  /\bremove_(?:column|columns|reference|references|index)\b/ => "remove operation",
  /\bdrop_table\b/ => "drop_table",
  /\brename_(?:column|table)\b/ => "rename operation",
  /\bchange_column(?:_default|_null)?\b/ => "in-place column change",
  /\b(?:DROP|TRUNCATE|DELETE\s+FROM)\b/i => "destructive SQL",
  /\bsafety_assured\b/ => "safety override",
  /\bforce:\s*true\b/ => "forced table replacement"
}.freeze

def forward_migration_source(source)
  method_starts = source.to_enum(:scan, /^\s*def\s+(up|change)\b/).map { Regexp.last_match }
  method_starts.filter_map do |match|
    body_start = match.end(0)
    body_end = source.index(/^\s*def\s+\w+\b/, body_start) || source.length
    source[body_start...body_end]
  end.join("\n")
end

violations = changed_output.lines(chomp: true).flat_map do |relative_path|
  source = forward_migration_source(File.read(File.join(root, relative_path)))
  destructive_patterns.filter_map do |pattern, description|
    "#{relative_path}: #{description}" if source.match?(pattern)
  end
end

if violations.any?
  warn "Expand/contract migration gate failed:"
  violations.each { |violation| warn "- #{violation}" }
  exit 1
end

puts "Expand/contract migration gate passed (#{changed_output.lines.count} changed migration(s))."
