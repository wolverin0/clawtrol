# Seed nightshift missions from the original hardcoded MISSIONS array
missions = [
  { name: "Dependency Updates", description: "Scan 12 active projects for outdated deps, run npm audit. Only on new commits.", model: "codex", estimated_minutes: 45, icon: "🔧", frequency: "weekly", days_of_week: [1], category: "code", position: 1 },
  { name: "ISP Network Health Report", description: "Pull UISP metrics + MikroTik data, analyze signal quality, predict failures.", model: "gemini", estimated_minutes: 20, icon: "📡", frequency: "manual", category: "network", position: 2 },
  { name: "Customer Churn Analysis", description: "Analyze UISP billing + usage patterns, identify at-risk customers.", model: "gemini", estimated_minutes: 30, icon: "💰", frequency: "manual", category: "finance", position: 3 },
  { name: "Security Scan", description: "npm audit + bundler-audit + Docker image scan + server hardening. Only on new commits.", model: "codex", estimated_minutes: 30, icon: "🔒", frequency: "weekly", days_of_week: [1], category: "security", position: 4 },
  { name: "Financial Intelligence", description: "Firefly III daily P&L, anomaly detection, billing reconciliation.", model: "gemini", estimated_minutes: 15, icon: "📊", frequency: "weekly", days_of_week: [5], category: "finance", position: 5 },
  { name: "Network Documentation", description: "Auto-generate IP maps, router configs, network diagrams from MikroTik/UISP.", model: "codex", estimated_minutes: 40, icon: "📝", frequency: "manual", category: "network", position: 6 },
  { name: "Competitor Intelligence", description: "Monitor competitor ISP websites and pricing, generate weekly report.", model: "gemini", estimated_minutes: 20, icon: "🕵️", frequency: "weekly", days_of_week: [5], category: "research", position: 7 },
  { name: "Social Media Pipeline", description: "Research trends, generate post ideas and copy for Punto Futura.", model: "gemini", estimated_minutes: 25, icon: "📱", frequency: "manual", category: "social", position: 8 },
  { name: "Codebase Health Scan", description: "Complexity metrics, dead code detection, test coverage gaps. Only on new commits.", model: "codex", estimated_minutes: 45, icon: "🧹", frequency: "weekly", days_of_week: [3], category: "code", position: 9 },
  { name: "UISP Signal Quality Report", description: "Detailed per-client signal analysis with degradation alerts.", model: "gemini", estimated_minutes: 15, icon: "📡", frequency: "manual", category: "network", position: 10 },
  { name: "Backup Validation", description: "Verify all database backups completed successfully, test restore.", model: "glm", estimated_minutes: 10, icon: "🔄", frequency: "always", category: "infra", position: 11 },
  { name: "Docker Health Deep Scan", description: "Container resource usage, image updates, security scan.", model: "glm", estimated_minutes: 15, icon: "🐳", frequency: "always", category: "infra", position: 12 },
  { name: "WhatsApp Bot Log Analyzer", description: "Parse wisp-bot and whatsapp-dashboard logs for errors and warnings.", model: "glm", estimated_minutes: 10, icon: "💬", frequency: "manual", category: "infra", position: 13 },
  { name: "Email Digest", description: "Summarize unread emails via gog gmail, highlight important ones.", model: "glm", estimated_minutes: 10, icon: "📧", frequency: "always", category: "general", position: 14 },
  { name: "Test Generator", description: "Generate unit tests for recent commits across 12 active projects.", model: "glm", estimated_minutes: 30, icon: "🧪", frequency: "weekly", days_of_week: [3], category: "code", position: 15 },
  { name: "Project Documentation (RAG)", description: "Generate detailed technical docs for all active projects, index in Qdrant.", model: "glm", estimated_minutes: 45, icon: "📚", frequency: "manual", category: "code", position: 16 },
  { name: "ISP Response Templates", description: "Generate/update customer response templates for common ISP situations.", model: "glm", estimated_minutes: 15, icon: "💬", frequency: "manual", category: "social", position: 17 },
  { name: "Dependency Mapper", description: "Map which services each project uses (DB, APIs, queues) for blast radius analysis.", model: "glm", estimated_minutes: 20, icon: "🔗", frequency: "manual", category: "infra", position: 18 },
  { name: "Toolchain Version Checker", description: "Check for updates: OpenClaw, Claude Code, Gemini CLI, Codex CLI, Node.js, Ruby, Rails, n8n.", model: "glm", estimated_minutes: 10, icon: "🔄", frequency: "manual", category: "infra", position: 19 }
]

missions.each do |attrs|
  NightshiftMission.find_or_create_by!(name: attrs[:name]) do |m|
    m.assign_attributes(attrs.except(:name))
  end
end

puts "✅ Seeded #{NightshiftMission.count} nightshift missions"
