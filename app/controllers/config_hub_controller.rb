# frozen_string_literal: true

# Central navigation hub for all OpenClaw config pages.
# Groups config pages by category for easy discovery.
class ConfigHubController < ApplicationController
  include GatewayClientAccessible

  # GET /config
  def show
    @gateway_configured = gateway_configured?
    @health = @gateway_configured ? gateway_client.health : nil
    @sections = config_sections
  end

  private

  def config_sections
    [
      {
        title: "🌐 Channels",
        description: "Configure messaging platform integrations",
        pages: [
          { name: "Telegram",   icon: "📱", path: telegram_config_path,                    desc: "Streaming, commands, link preview, proxy, topics" },
          { name: "Discord",    icon: "🎮", path: discord_config_path,                     desc: "Guilds, channels, actions, reactions, user allowlist" },
          { name: "Mattermost", icon: "💬", path: channel_config_path(channel: "mattermost"), desc: "Chat mode, server URL, team config" },
          { name: "Slack",      icon: "🔷", path: channel_config_path(channel: "slack"),    desc: "Socket mode, thread mode, slash commands" },
          { name: "Signal",     icon: "🔒", path: channel_config_path(channel: "signal"),   desc: "Reaction modes, group handling" },
          { name: "Accounts",   icon: "👤", path: channel_accounts_path,                   desc: "Multi-account management per channel" }
        ]
      },
      {
        title: "🤖 Agent & Identity",
        description: "Configure bot personality and behavior",
        pages: [
          { name: "Identity & Branding", icon: "🎨", path: identity_config_path, desc: "Name, emoji, avatar, message prefixes" },
          { name: "Agent Config",        icon: "🤖", path: agent_config_path,    desc: "Multi-agent setup, workspaces, tools" },
          { name: "Agent Personas",      icon: "🎭", path: agent_personas_path,  desc: "Persona templates for sub-agents" },
          { name: "DM Policy",           icon: "🔐", path: dm_policy_path,       desc: "Pairing, allowlist, open, disabled" },
          { name: "DM Scope Audit",      icon: "🔍", path: dm_scope_audit_path,  desc: "Session isolation security check" },
          { name: "Send Policy",         icon: "📮", path: send_policy_path,     desc: "Rules and access groups" }
        ]
      },
      {
        title: "⚙️ System",
        description: "Gateway, reload, logging, and environment",
        pages: [
          { name: "Gateway Config",  icon: "🛠️", path: gateway_config_path,  desc: "Full config editor with hot-reload" },
          { name: "Hot Reload",      icon: "🔥", path: hot_reload_path,      desc: "Reload mode, debounce, field classification" },
          { name: "Logging & Debug", icon: "📋", path: logging_config_path,  desc: "Log levels, console style, debug commands" },
          { name: "Env Variables",   icon: "🔐", path: env_manager_path,     desc: "View .env vars, test substitution" },
          { name: "API Keys",        icon: "🔑", path: keys_path,            desc: "Manage API keys and tokens" }
        ]
      },
      {
        title: "🧩 Tools & Skills",
        description: "Manage skills, plugins, and exec permissions",
        pages: [
          { name: "Skill Manager",   icon: "🧩", path: skill_manager_path,   desc: "Browse, install, configure skills" },
          { name: "Exec Approvals",  icon: "🔐", path: exec_approvals_path,  desc: "Per-node command allowlists" },
          { name: "CLI Backends",    icon: "💻", path: cli_backends_path,    desc: "Text-only fallback CLIs" },
          { name: "Sandbox Config",  icon: "📦", path: sandbox_config_path,  desc: "Docker sandbox settings" }
        ]
      },
      {
        title: "📡 Session & Streaming",
        description: "Session management and message delivery",
        pages: [
          { name: "Session Maintenance", icon: "🏥", path: session_maintenance_path, desc: "Pruning, rotation, cleanup" },
          { name: "Compaction Config",   icon: "📐", path: compaction_config_path,   desc: "Context pruning and memory flush" },
          { name: "Block Streaming",     icon: "📡", path: block_streaming_path,     desc: "Chunk sizes, break preference" },
          { name: "Typing Indicator",    icon: "⌨️", path: typing_config_path,       desc: "Typing modes and intervals" },
          { name: "Identity Links",      icon: "🔗", path: identity_links_path,      desc: "Cross-channel user mapping" }
        ]
      },
      {
        title: "🔄 Automation",
        description: "Cron jobs, webhooks, and heartbeat",
        pages: [
          { name: "Cron Manager",       icon: "⏰", path: cronjobs_path,         desc: "Schedule and manage cron jobs" },
          { name: "Heartbeat Config",   icon: "💓", path: heartbeat_config_path, desc: "Interval, model, prompt settings" },
          { name: "Webhook Mappings",   icon: "🪝", path: webhook_mappings_path, desc: "Visual webhook mapping builder" },
          { name: "Hooks Dashboard",    icon: "📊", path: hooks_dashboard_path,  desc: "Active hooks and Gmail PubSub" }
        ]
      }
    ]
  end
end
