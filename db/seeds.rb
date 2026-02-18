# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create global task templates
puts "Creating global task templates..."
TaskTemplate::DEFAULTS.each do |slug, config|
  TaskTemplate.find_or_create_by!(slug: slug, global: true) do |t|
    t.name = config[:name]
    t.icon = config[:icon]
    t.model = config[:model]
    t.priority = config[:priority] || 0
    t.validation_command = config[:validation_command]
    t.description_template = config[:description_template]
    t.user = nil
  end
end
puts "Created #{TaskTemplate.global_templates.count} global templates: #{TaskTemplate.global_templates.pluck(:slug).join(', ')}"

# Nightshift missions
load Rails.root.join("db/seeds/nightshift_missions.rb")

# Built-in factory agents
load Rails.root.join("db/seeds/factory_agents.rb")

# ZeroClaw agents (idempotent)
[
  { name: "builder-1", url: "http://localhost:18088", mode: "webhook", status: "active" },
  { name: "builder-2", url: "http://localhost:18089", mode: "webhook", status: "active" },
  { name: "mei-ling", url: "http://localhost:18082", mode: "webhook", status: "active" }
].each do |attrs|
  ZeroclawAgent.find_or_create_by!(name: attrs[:name]) do |a|
    a.url = attrs[:url]
    a.mode = attrs[:mode]
    a.status = attrs[:status]
  end
end
