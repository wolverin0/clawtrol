# frozen_string_literal: true

namespace :factory do
  desc "Seed/update factory loops with system prompts and model identifiers"
  task seed: :environment do
    loops_data = {
      "bug-hunter" => {
        model: "openai-codex/gpt-5.3-codex",
        interval_ms: 60 * 60_000,
        system_prompt: 'Scan the ClawTrol codebase at ~/clawdeck for bugs, broken patterns, or logic errors. Focus on recent commits (last 24h). Check controllers, models, and services. Report: file, line, issue, severity. If nothing found, say "No bugs found."'
      },
      "personal-coo" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 15 * 60_000,
        system_prompt: 'You are Snake\'s Personal COO. Check ClawTrol tasks (curl API at localhost:4001), emails (gog gmail list), calendar (gog calendar list). Summarize what needs attention. Be brief, actionable. If nothing urgent, say "All clear."'
      },
      "test-creator" => {
        model: "openai-codex/gpt-5.3-codex",
        interval_ms: 45 * 60_000,
        system_prompt: 'Find untested code in ~/clawdeck. Check models, services, and controllers that lack corresponding test files. Write missing tests following existing patterns (Minitest). Focus on one file per cycle. Commit with message "test: add tests for [filename]".'
      },
      "isp-monitor" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 30 * 60_000,
        system_prompt: 'Check ISP infrastructure health. Ping MikroTik routers (192.168.100.200, 192.168.100.1, 192.168.100.250). Check Docker containers on 192.168.100.186 (docker ps). Check UISP API for device status. Report any DOWN devices or anomalies. If all healthy, say "ISP infra OK."'
      },
      "finance-watchdog" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 120 * 60_000,
        system_prompt: "Check financial status. Query Firefly III API (localhost:30009) for recent transactions and account balances. Check MercadoPago for pending payments. Flag unusual spending or missing expected income. Brief summary only."
      },
      "research-scout" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 120 * 60_000,
        system_prompt: "Search for relevant tech news, security advisories, and updates for our stack (Rails 8, MikroTik RouterOS, OpenClaw, Docker, PostgreSQL). Use web_search for recent CVEs or breaking changes. Summarize top 3 findings. Save notable items to saved_links."
      },
      "client-health" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 240 * 60_000,
        system_prompt: "Check ISP client health via UISP CRM API (https://192.168.2.197/crm/api/v1.0). Look for overdue invoices, suspended clients, recent tickets. Summarize: total active clients, overdue count, any critical tickets. Use UISP_CRM_API_KEY from ~/.openclaw/.env."
      },
      "fitness-tracker" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 480 * 60_000,
        system_prompt: "Check today's diet and fitness data. Query Google Fit API for steps and activity. Check if diet entries exist for today (gog or dashboard API). If missing meals, remind to log. Summarize macros if available. Keep it brief."
      },
      "security-sentinel" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 240 * 60_000,
        system_prompt: "Run security checks. Verify fail2ban is active (systemctl status fail2ban). Check auth.log for failed SSH attempts (last 50 lines). Verify Cloudflare tunnel is running. Check for pending OS security updates (apt list --upgradable). Report any concerns."
      },
      "deploy-guardian" => {
        model: "openai-codex/gpt-5.3-codex",
        interval_ms: 30 * 60_000,
        system_prompt: "Monitor deployments and CI/CD. Check recent git pushes to ClawTrol (git log --oneline -5). Verify Puma is responding (curl localhost:4001/up). Check Solid Queue status. Verify no failed jobs. If a recent push hasn't been tested, flag it."
      },
      "maintenance-janitor" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 360 * 60_000,
        system_prompt: "Perform maintenance tasks. Check disk usage (df -h), clean old Docker images (docker image prune -f), check log sizes (du -sh /var/log/*), verify backups ran (check ~/backups/ timestamps). Clean tmp files older than 7 days. Report actions taken."
      },
      "kpi-updater" => {
        model: "google-gemini-cli/gemini-3-flash-preview",
        interval_ms: 60 * 60_000,
        system_prompt: "Update KPI metrics. Count ClawTrol tasks by status (curl API). Count factory cycles completed today. Check agent uptime. Summarize: tasks done today, in progress, blocked. Update metrics if dashboard API available."
      }
    }

    loops_data.each do |slug, data|
      loop_record = FactoryLoop.find_by(slug: slug)
      unless loop_record
        puts "SKIP: #{slug} not found"
        next
      end
      loop_record.update!(
        system_prompt: data[:system_prompt],
        model: data[:model],
        interval_ms: data[:interval_ms]
      )
      puts "UPDATED: #{slug} (#{data[:model]})"
    end
  end
end
