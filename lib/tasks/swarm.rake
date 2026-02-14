namespace :swarm do
  task seed: :environment do
    user = User.first
    ideas = [
      { title: "Audit ClawTrol security headers", category: "infra", suggested_model: "codex", difficulty: "standard", pipeline_type: "feature", icon: "🔒", estimated_minutes: 20 },
      { title: "Add dark/light theme toggle persistence", category: "code", suggested_model: "codex", difficulty: "standard", pipeline_type: "feature", icon: "🎨", estimated_minutes: 30 },
      { title: "Research Cursor vs Claude Code for ISP workflow", category: "research", suggested_model: "flash", difficulty: "trivial", pipeline_type: "research", icon: "🔍", estimated_minutes: 15 },
      { title: "Generate FuturaFitness social media flyers", category: "marketing", suggested_model: "gemini", difficulty: "standard", pipeline_type: "research", icon: "💪", estimated_minutes: 20 },
      { title: "Optimize PersonalDashboard API response times", category: "code", suggested_model: "codex", difficulty: "complex", pipeline_type: "feature", icon: "⚡", estimated_minutes: 45 },
      { title: "Check MikroTik CVE updates", category: "infra", suggested_model: "flash", difficulty: "trivial", pipeline_type: "research", icon: "🛡️", estimated_minutes: 10 },
      { title: "Analyze WhatsApp bot error patterns", category: "research", suggested_model: "gemini", difficulty: "standard", pipeline_type: "research", icon: "📊", estimated_minutes: 20 },
      { title: "Build Firefly III budget dashboard widget", category: "finance", suggested_model: "codex", difficulty: "complex", pipeline_type: "feature", icon: "💰", estimated_minutes: 45 },
      { title: "Review UISP invoice automation accuracy", category: "infra", suggested_model: "flash", difficulty: "trivial", pipeline_type: "research", icon: "📄", estimated_minutes: 15 },
      { title: "Add macro tracking API to PersonalDashboard", category: "fitness", suggested_model: "codex", difficulty: "standard", pipeline_type: "feature", icon: "🥩", estimated_minutes: 30 },
      { title: "Create FuturaDelivery promotional landing page", category: "marketing", suggested_model: "codex", difficulty: "standard", pipeline_type: "feature", icon: "🚚", estimated_minutes: 30 },
      { title: "Benchmark Qdrant vs pgvector for RAG", category: "research", suggested_model: "flash", difficulty: "standard", pipeline_type: "research", icon: "🧠", estimated_minutes: 20 },
      { title: "Add webhook retry logic to ClawTrol", category: "code", suggested_model: "codex", difficulty: "standard", pipeline_type: "bug-fix", icon: "🔄", estimated_minutes: 25 },
      { title: "Scan network for rogue devices", category: "infra", suggested_model: "glm", difficulty: "trivial", pipeline_type: "quick-fix", icon: "📡", estimated_minutes: 10 },
      { title: "Design Nereidas onboarding flow", category: "code", suggested_model: "codex", difficulty: "complex", pipeline_type: "feature", icon: "🧜", estimated_minutes: 45 },
      { title: "Research n8n alternatives (Temporal, Windmill)", category: "research", suggested_model: "flash", difficulty: "standard", pipeline_type: "research", icon: "🔀", estimated_minutes: 20 },
      { title: "Add ClawTrol task dependency visualization", category: "code", suggested_model: "codex", difficulty: "complex", pipeline_type: "feature", icon: "🕸️", estimated_minutes: 45 },
      { title: "Create weekly ISP client retention report", category: "research", suggested_model: "gemini", difficulty: "standard", pipeline_type: "research", icon: "📈", estimated_minutes: 20 },
      { title: "Implement Pedrito push notifications", category: "code", suggested_model: "codex", difficulty: "standard", pipeline_type: "feature", icon: "🔔", estimated_minutes: 30 },
      { title: "Deep research: AI agent frameworks comparison 2026", category: "research", suggested_model: "flash", difficulty: "standard", pipeline_type: "research", icon: "🤖", estimated_minutes: 30 }
    ]
    ideas.each do |attrs|
      SwarmIdea.find_or_create_by!(user: user, title: attrs[:title]) do |idea|
        idea.assign_attributes(attrs.merge(source: "manual"))
      end
    end
    puts "Seeded #{ideas.size} swarm ideas"
  end
end
