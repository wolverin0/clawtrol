module NavigationHelper
  def last_board_navigation_path
    last_board_id = session[:last_board_id]
    return boards_path unless current_user && last_board_id.present?

    board = current_user.boards.order(position: :asc).find_by(id: last_board_id)
    board ? board_path(board) : boards_path
  end

  def primary_navigation
    # Memoize to avoid evaluating multiple times per request
    @primary_navigation ||= begin
      last_board_path = last_board_navigation_path

      learning_count = respond_to?(:pending_learning_proposals_count) ? pending_learning_proposals_count.to_i : 0

      [
        {
          id: :tasks,
          label: "Tasks",
          icon: "📋",
          controllers: %w[boards workflows],
          items: [
            { label: "Board", icon: "📋", url: last_board_path, controller: "boards" },
            { label: "Workflows", icon: "🔄", url: workflows_path, controller: "workflows" }
          ]
        },
        {
          id: :agents,
          label: "Agents",
          icon: "🤖",
          controllers: %w[factory nightshift zerobitch sessions_explorer nodes skill_manager agent_personas agent_config],
          items: [
            { label: "Factory", icon: "🏭", url: factory_path, controller: "factory" },
            { label: "Nightshift", icon: "🌙", url: nightshift_path, controller: "nightshift" },
            (defined?(zerobitch_path) ? { label: "ZeroBitch", icon: "🎯", url: zerobitch_path, controller: "zerobitch" } : nil),
            { label: "Sessions", icon: "💬", url: sessions_explorer_path, controller: "sessions_explorer" },
            { label: "Nodes", icon: "📱", url: nodes_path, controller: "nodes" },
            { label: "Skills", icon: "🧩", url: skill_manager_path, controller: "skill_manager" },
            { type: :separator },
            { type: :label, text: "Personas" },
            { label: "Agent Personas", icon: "🤖", url: agent_personas_path, controller: "agent_personas", exact_action: false },
            { label: "Roster", icon: "📋", url: roster_agent_personas_path, controller: "agent_personas", action: "roster" },
            { label: "Multi-Agent Config", icon: "⚙️", url: agent_config_path, controller: "agent_config" }
          ].compact
        },
        {
          id: :data,
          label: "Data",
          icon: "📊",
          controllers: %w[analytics tokens previews audits showcases],
          items: [
            { label: "Dashboard", icon: "📊", url: board_path(1), controller: "boards", id_param: "1" },
            { label: "Analytics", icon: "📈", url: analytics_path, controller: "analytics" },
            { label: "Tokens", icon: "💰", url: tokens_path, controller: "tokens" },
            { label: "Outputs", icon: "👁️", url: outputs_path, controller: "previews" },
            { label: "Self-Audit", icon: "🔍", url: dm_scope_audit_path, controller: "audits" },
            { label: "Showcase", icon: "✨", url: showcases_path, controller: "showcases" }
          ]
        },
        {
          id: :tools,
          label: "Tools",
          icon: "🛠️",
          controllers: %w[command terminal saved_links learning_proposals webhook_mappings],
          items: [
            { label: "Command", icon: "💻", url: command_path, controller: "command" },
            { label: "Terminal", icon: "🖥️", url: terminal_path, controller: "terminal" },
            { label: "Saved Links", icon: "🔖", url: saved_links_path, controller: "saved_links" },
            { label: "Learning Inbox", icon: "🧠", url: learning_proposals_path, controller: "learning_proposals", badge: (learning_count > 0 ? learning_count : nil) },
            { label: "Webhooks", icon: "🔁", url: webhook_mappings_path, controller: "webhook_mappings" },
            { label: "Docs Hub", icon: "📚", url: Rails.application.config.x.openclaw.docs_hub_url, external: true }
          ]
        },
        {
          id: :config,
          label: "Config",
          icon: "⚙️",
          controllers: %w[gateway_config soul_editor],
          items: [
            { label: "Gateway Config", icon: "⚙️", url: gateway_config_path, controller: "gateway_config" },
            (defined?(soul_editor_path) ? { label: "Soul Editor", icon: "❤️", url: soul_editor_path, controller: "soul_editor" } : nil)
          ].compact
        }
      ]
    end
  end

  def nav_item_active?(item)
    return false if item[:controller].blank?

    is_active = controller_name == item[:controller]
    is_active &&= action_name == item[:action] if item.key?(:action)
    is_active &&= params[:id].to_s == item[:id_param] if item.key?(:id_param)

    if item[:exact_action] == false
      # Special case for Agent Personas index vs roster
      is_active &&= action_name != "roster"
    end

    is_active
  end
end
