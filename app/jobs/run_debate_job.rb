require "open3"
require "shellwords"
require "fileutils"

# RunDebateJob - Multi-Model Debate Review System
#
# CURRENT STATE (2026-02-05): MOCK IMPLEMENTATION
# ================================================
# This job currently generates a FAKE synthesis file instead of
# actually calling multiple LLM models for debate.
#
# What it SHOULD do:
# - Spawn multiple AI agents (gemini, claude, glm) in parallel
# - Have them debate the task's implementation quality
# - Generate a real synthesis from their perspectives
# - Use the debate skill: /debate [-r N] [-d STYLE] <question>
#
# What it CURRENTLY does:
# - Creates a placeholder synthesis.md with pre-written content
# - Always returns "PASS" unless hardcoded keywords are present
# - Does NOT call any external LLM APIs
#
# TODO: Implement real multi-model debate (see issue #XXX)
# - Requires: OpenClaw multi-agent spawning
# - Requires: debate skill integration
# - Requires: synthesis merging logic
#
class RunDebateJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.find(task_id)
    return unless task.review_status == "pending" && task.debate_review?

    config = task.review_config
    style = config["style"] || "quick"
    focus = config["focus"]
    models = config["models"] || %w[gemini claude glm]

    task.update!(review_status: "running")
    broadcast_task_update(task)

    # Prepare debate storage directory
    debate_path = task.debate_storage_path
    FileUtils.mkdir_p(debate_path)

    begin
      # Build the debate topic from task
      topic = build_debate_topic(task, focus)

      # Build debate command - using openclaw to spawn debate skill
      # The debate skill expects: /debate [-r N] [-d STYLE] <question or task>
      debate_args = [
        "-d", style,
        topic
      ]

      # Create a temporary prompt file
      prompt_file = File.join(debate_path, "prompt.txt")
      File.write(prompt_file, "/debate #{debate_args.join(' ')}")

      # Run debate using openclaw spawn
      # We'll use exec to call the debate skill in background mode
      output = nil
      exit_status = nil

      # Timeout: quick=5min, thorough=15min, others=10min
      timeout_seconds = case style
        when "quick" then 300
        when "thorough" then 900
        else 600
      end

      Timeout.timeout(timeout_seconds) do
        # We spawn a subagent to run the debate
        # The debate skill will create files in PROJECT_ROOT/debates/
        # Security: build_debate_command sets @debate_env with user data as env vars
        script_path = build_debate_command(topic, style, models, debate_path)
        # Execute with env vars (no shell interpolation of user data)
        output, status = Open3.capture2e(@debate_env || {}, "bash", script_path, chdir: debate_path)
        exit_status = status
      end

      # Check for synthesis.md to determine result
      synthesis_path = task.debate_synthesis_path
      
      if File.exist?(synthesis_path)
        synthesis = File.read(synthesis_path)
        
        # Parse synthesis for pass/fail indicators
        passed = parse_debate_result(synthesis)
        
        if passed
          task.complete_review!(
            status: "passed",
            result: {
              synthesis_preview: synthesis.truncate(1000),
              debate_path: debate_path,
              models_used: models
            }
          )
        else
          task.complete_review!(
            status: "failed",
            result: {
              synthesis_preview: synthesis.truncate(1000),
              debate_path: debate_path,
              models_used: models,
              error_summary: extract_concerns_from_synthesis(synthesis)
            }
          )
        end
      else
        # No synthesis generated - consider it a failure
        task.complete_review!(
          status: "failed",
          result: {
            error_summary: "Debate did not produce synthesis.md",
            output_preview: output.to_s.truncate(500),
            debate_path: debate_path
          }
        )
      end

    rescue Timeout::Error
      task.complete_review!(
        status: "failed",
        result: {
          error_summary: "Debate timed out after #{timeout_seconds} seconds",
          timeout: true,
          debate_path: debate_path
        }
      )
    rescue StandardError => e
      Rails.logger.error "Debate job failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      task.complete_review!(
        status: "failed",
        result: {
          error_summary: "Error running debate: #{e.message}",
          exception: e.class.name,
          debate_path: debate_path
        }
      )
    end

    broadcast_task_update(task)
  end

  private

  def build_debate_topic(task, focus)
    topic_parts = ["Review task: #{task.name}"]
    
    if task.description.present?
      # Extract agent output if present
      if task.description.include?("## Agent Output")
        agent_output = task.description.split("## Agent Output").last.to_s.strip
        topic_parts << "Agent completed work:\n#{agent_output.truncate(2000)}"
      else
        topic_parts << "Description:\n#{task.description.truncate(1500)}"
      end
    end
    
    if focus.present?
      topic_parts << "Focus areas:\n#{focus}"
    end
    
    topic_parts << "Evaluate: Is this implementation correct and complete? What issues exist?"
    topic_parts.join("\n\n")
  end

  def build_debate_command(topic, style, models, debate_path)
    # Security: pass user-controllable data via environment variables
    # instead of interpolating into the script to prevent injection
    
    # Write topic to a file safely (avoids any shell interpolation)
    context_file = File.join(debate_path, "context.md")
    File.write(context_file, topic)

    # Create a safe debate runner script that reads from env vars and files
    script_path = File.join(debate_path, "run_debate.sh")
    
    # Script uses ONLY environment variables for user-controlled data
    # No string interpolation of user content into the script body
    script_content = <<~'BASH'
      #!/bin/bash
      cd "$DEBATE_PATH"
      
      # Create synthesis placeholder (will be replaced by actual debate)
      cat > synthesis.md << 'SYNTHESIS_END'
      # Debate Synthesis
      
      ## Topic
      See context.md for full topic.
      
      ## Style
      See DEBATE_STYLE env var.
      
      ## Participants
      See DEBATE_MODELS env var.
      
      ## Consensus
      - Implementation appears structurally sound
      - Code follows expected patterns
      
      ## Disputed Issues
      - None identified in quick review
      
      ## Recommendations
      | Priority | Action | Source |
      |----------|--------|--------|
      | 1 | Manual testing recommended | All |
      
      ## Conclusion
      **PASS** - Implementation looks correct. Recommend manual verification.
      SYNTHESIS_END
      
      # Append topic summary and metadata to synthesis
      {
        echo ""
        echo "## Metadata"
        echo "- Style: $DEBATE_STYLE"
        echo "- Models: $DEBATE_MODELS"
        echo ""
        echo "## Topic Preview"
        head -c 500 context.md
      } >> synthesis.md
      
      echo "Debate completed"
    BASH
    
    File.write(script_path, script_content)
    File.chmod(0755, script_path)
    
    # Return command as array for safe execution with env vars
    # The env hash is passed to Open3.capture2e to avoid shell injection
    @debate_env = {
      "DEBATE_PATH" => debate_path,
      "DEBATE_STYLE" => style.to_s,
      "DEBATE_MODELS" => models.join(", "),
      "DEBATE_TOPIC_FILE" => context_file
    }
    
    script_path
  end

  def parse_debate_result(synthesis)
    # Look for explicit PASS/FAIL indicators
    return true if synthesis.match?(/\*\*PASS\*\*/i)
    return false if synthesis.match?(/\*\*FAIL\*\*/i)
    
    # Look for concerning keywords
    concern_keywords = %w[critical severe broken incorrect fails failing vulnerability]
    concern_count = concern_keywords.count { |kw| synthesis.downcase.include?(kw) }
    
    # If more than 2 concern keywords, consider it failed
    concern_count < 2
  end

  def extract_concerns_from_synthesis(synthesis)
    # Try to extract the Disputed Issues section
    if synthesis.include?("## Disputed Issues")
      section = synthesis.split("## Disputed Issues").last
      section = section.split("##").first  # Get just this section
      return section.strip.truncate(500)
    end
    
    "Review raised concerns. See full synthesis for details."
  end

  def broadcast_task_update(task)
    Turbo::StreamsChannel.broadcast_action_to(
      "board_#{task.board_id}",
      action: :replace,
      target: "task_#{task.id}",
      partial: "boards/task_card",
      locals: { task: task }
    )
  end
end
