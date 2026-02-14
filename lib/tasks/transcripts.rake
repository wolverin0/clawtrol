namespace :transcripts do
  desc "Backfill agent_transcripts from storage/agent_activity and live sessions"
  task backfill: :environment do
    captured = 0
    skipped = 0
    failed = 0

    Dir.glob(Rails.root.join("storage/agent_activity/task-*-session-*.jsonl")).each do |path|
      basename = File.basename(path)
      match = basename.match(/task-(\d+)-session-(.+)\.jsonl/)
      next unless match

      task_id = match[1].to_i
      session_id = match[2]

      task = Task.find_by(id: task_id)
      task_run = TaskRun.find_by(run_id: session_id) || TaskRun.find_by(task_id: task_id)

      begin
        AgentTranscript.capture_from_jsonl!(path, task: task, task_run: task_run, session_id: session_id)
        captured += 1
      rescue ActiveRecord::RecordNotUnique
        skipped += 1
      rescue StandardError => e
        failed += 1
        puts "FAIL #{path}: #{e.message}"
      end
    end

    puts "Phase 1 (storage): captured=#{captured} skipped=#{skipped} failed=#{failed}"

    captured2 = 0
    Dir.glob(File.expand_path("~/.openclaw/agents/main/sessions/*.jsonl")).each do |path|
      session_id = File.basename(path, ".jsonl")
      next if session_id.include?(".deleted")
      next if AgentTranscript.exists?(session_id: session_id)

      task = Task.find_by(agent_session_id: session_id)
      task_run = TaskRun.find_by(run_id: session_id)

      begin
        AgentTranscript.capture_from_jsonl!(path, task: task, task_run: task_run, session_id: session_id)
        captured2 += 1
      rescue StandardError => e
        puts "FAIL #{session_id}: #{e.message}"
      end
    end

    puts "Phase 2 (live): captured=#{captured2}"
    puts "Total agent_transcripts: #{AgentTranscript.count}"
  end
end
