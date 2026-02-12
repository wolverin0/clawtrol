class NightshiftController < ApplicationController
  skip_forgery_protection only: :launch

  def index
    @missions = nightshift_missions
    @selections = NightshiftSelection.for_tonight.index_by(&:mission_id)
    @total_time = @missions.sum { |m| m[:time] }
  end

  def launch
    selected_ids = params[:mission_ids]&.map(&:to_i) || []
    missions = nightshift_missions.select { |m| selected_ids.include?(m[:id]) }
    
    existing_selections = NightshiftSelection.for_tonight.where(mission_id: selected_ids).index_by(&:mission_id)

    missions_to_create = missions.reject { |m| existing_selections[m[:id]] }

    new_selections = missions_to_create.map do |mission|
      {
        mission_id: mission[:id],
        title: mission[:title],
        scheduled_date: Date.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    if new_selections.any?
      NightshiftSelection.insert_all(new_selections)
    end
    
    NightshiftSelection.for_tonight.where(mission_id: selected_ids).update_all(enabled: true)
    NightshiftSelection.for_tonight.where.not(mission_id: selected_ids).update_all(enabled: false)

    render json: { success: true, armed_count: selected_ids.count }, status: :ok
  end

  MISSIONS = [
      { id: 1, title: "Dependency Updates", desc: "Scan 12 active projects for outdated deps, run npm audit. Only on new commits.", model: "codex", time: 45, icon: "🔧" },
      { id: 2, title: "ISP Network Health Report", desc: "Pull UISP metrics + MikroTik data, analyze signal quality, predict failures.", model: "gemini", time: 20, icon: "📡" },
      { id: 3, title: "Customer Churn Analysis", desc: "Analyze UISP billing + usage patterns, identify at-risk customers.", model: "gemini", time: 30, icon: "💰" },
      { id: 4, title: "Security Scan", desc: "npm audit + bundler-audit + Docker image scan + server hardening. Only on new commits.", model: "codex", time: 30, icon: "🔒" },
      { id: 5, title: "Financial Intelligence", desc: "Firefly III daily P&L, anomaly detection, billing reconciliation.", model: "gemini", time: 15, icon: "📊" },
      { id: 6, title: "Network Documentation", desc: "Auto-generate IP maps, router configs, network diagrams from MikroTik/UISP.", model: "codex", time: 40, icon: "📝" },
      { id: 7, title: "Competitor Intelligence", desc: "Monitor competitor ISP websites and pricing, generate weekly report.", model: "gemini", time: 20, icon: "🕵️" },
      { id: 8, title: "Social Media Pipeline", desc: "Research trends, generate post ideas and copy for Punto Futura.", model: "gemini", time: 25, icon: "📱" },
      { id: 9, title: "Codebase Health Scan", desc: "Complexity metrics, dead code detection, test coverage gaps. Only on new commits.", model: "codex", time: 45, icon: "🧹" },
      { id: 10, title: "UISP Signal Quality Report", desc: "Detailed per-client signal analysis with degradation alerts.", model: "gemini", time: 15, icon: "📡" },
      { id: 11, title: "Backup Validation", desc: "Verify all database backups completed successfully, test restore.", model: "glm", time: 10, icon: "🔄" },
      { id: 12, title: "Docker Health Deep Scan", desc: "Container resource usage, image updates, security scan.", model: "glm", time: 15, icon: "🐳" },
      { id: 13, title: "WhatsApp Bot Log Analyzer", desc: "Parse wisp-bot and whatsapp-dashboard logs for errors and warnings.", model: "glm", time: 10, icon: "💬" },
      { id: 14, title: "Email Digest", desc: "Summarize unread emails via gog gmail, highlight important ones.", model: "glm", time: 10, icon: "📧" },
      { id: 15, title: "Test Generator", desc: "Generate unit tests for recent commits across 12 active projects.", model: "glm", time: 30, icon: "🧪" },
      { id: 16, title: "Project Documentation (RAG)", desc: "Generate detailed technical docs for all active projects, index in Qdrant.", model: "glm", time: 45, icon: "📚" },
      { id: 17, title: "ISP Response Templates", desc: "Generate/update customer response templates for common ISP situations.", model: "glm", time: 15, icon: "💬" },
      { id: 18, title: "Dependency Mapper", desc: "Map which services each project uses (DB, APIs, queues) for blast radius analysis.", model: "glm", time: 20, icon: "🔗" },
  ].freeze

  private

  def nightshift_missions
    MISSIONS
  end
end
