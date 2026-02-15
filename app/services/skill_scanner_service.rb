# frozen_string_literal: true

# Scans OpenClaw skill directories and returns metadata for each skill.
# Reads SKILL.md files for descriptions and checks for gating requirements.
class SkillScannerService
  BUNDLED_SKILLS_DIR = File.expand_path("~/.npm-global/lib/node_modules/openclaw/skills")
  WORKSPACE_SKILLS_DIR = File.expand_path("~/.openclaw/workspace/skills")

  Skill = Data.define(:name, :source, :path, :description, :has_scripts, :has_config, :file_count)

  def self.call
    new.call
  end

  def call
    skills = []
    skills.concat(scan_directory(BUNDLED_SKILLS_DIR, source: "bundled"))
    skills.concat(scan_directory(WORKSPACE_SKILLS_DIR, source: "workspace"))
    skills.sort_by(&:name)
  end

  private

  def scan_directory(dir, source:)
    return [] unless File.directory?(dir)

    Dir.children(dir).filter_map do |name|
      skill_path = File.join(dir, name)
      next unless File.directory?(skill_path)

      skill_md = File.join(skill_path, "SKILL.md")
      description = extract_description(skill_md)
      has_scripts = Dir.glob(File.join(skill_path, "*.{sh,py,rb,js,ts}")).any?
      has_config = File.exist?(File.join(skill_path, "config.yml")) || File.exist?(File.join(skill_path, "config.yaml"))
      file_count = Dir.glob(File.join(skill_path, "**/*")).count { |f| File.file?(f) }

      Skill.new(
        name: name,
        source: source,
        path: skill_path,
        description: description,
        has_scripts: has_scripts,
        has_config: has_config,
        file_count: file_count
      )
    end
  end

  def extract_description(skill_md_path)
    return nil unless File.exist?(skill_md_path)

    content = File.read(skill_md_path, encoding: "utf-8")
    # Extract first paragraph after the title (skip # heading lines)
    lines = content.lines.map(&:strip)
    desc_lines = []
    past_heading = false

    lines.each do |line|
      if line.start_with?("#")
        past_heading = true
        next
      end
      next if !past_heading
      break if line.empty? && desc_lines.any?
      desc_lines << line unless line.empty?
    end

    desc_lines.join(" ").truncate(200).presence
  rescue StandardError
    nil
  end
end
