# frozen_string_literal: true

namespace :skill_store do
  desc "Ensure the Skill Store auto-update cron exists in OpenClaw"
  task provision_cron: :environment do
    cron_name = "🏪 Skill Store Auto-Update"
    script_path = File.expand_path("~/.openclaw/workspace/scripts/skill-store.sh")

    # Check if cron already exists
    list_output = `openclaw cron list --json 2>/dev/null`
    if list_output.include?(cron_name)
      puts "✅ Skill Store cron already exists"
      next
    end

    unless File.executable?(script_path)
      puts "❌ skill-store.sh not found or not executable at #{script_path}"
      next
    end

    # Create the cron: daily at 05:00 ART, isolated session, runs the update script
    system(
      "openclaw", "cron", "add",
      "--name", cron_name,
      "--cron", "0 8 * * *",  # 08:00 UTC = 05:00 ART
      "--tz", "America/Buenos_Aires",
      "--session", "isolated",
      "--message", "Run skill store update: exec ~/.openclaw/workspace/scripts/skill-store.sh update — then report what was updated (if anything) to Mission Control topic 24.",
      "--model", "cerebras-qwen"
    )

    puts "✅ Skill Store auto-update cron created (daily 05:00 ART)"
  end

  desc "Update skill store catalog and sync installed skills"
  task update: :environment do
    script = File.expand_path("~/.openclaw/workspace/scripts/skill-store.sh")
    system(script, "update")
  end
end
