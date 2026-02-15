# frozen_string_literal: true

# Visual builder for OpenClaw webhook hook mappings.
#
# OpenClaw supports `hooks.mappings` with match rules, templates, and JS transforms.
# This controller reads current mappings from the gateway config and provides a
# visual editor to create/edit/delete them.
class WebhookMappingsController < ApplicationController
  include GatewayClientAccessible
  before_action :ensure_gateway_configured!

  # GET /webhooks/mappings
  def index
    @config_data = gateway_client.config_get
    @mappings = extract_mappings(@config_data)
    @webhook_logs = current_user.webhook_logs.recent.limit(20) if current_user.respond_to?(:webhook_logs)
    @presets = mapping_presets
  end

  # POST /webhooks/mappings/save
  def save
    mappings_json = params[:mappings_json].to_s.strip
    if mappings_json.blank?
      render json: { success: false, error: "Mappings JSON required" }, status: :unprocessable_entity
      return
    end

    if mappings_json.bytesize > 128.kilobytes
      render json: { success: false, error: "Mappings too large (max 128KB)" }, status: :unprocessable_entity
      return
    end

    begin
      parsed = JSON.parse(mappings_json)
      unless parsed.is_a?(Array)
        render json: { success: false, error: "Mappings must be a JSON array" }, status: :unprocessable_entity
        return
      end

      # Validate each mapping has required fields
      parsed.each_with_index do |mapping, i|
        unless mapping.is_a?(Hash)
          render json: { success: false, error: "Mapping ##{i + 1} must be an object" }, status: :unprocessable_entity
          return
        end

        unless mapping["match"].is_a?(Hash) || mapping["source"].present?
          render json: { success: false, error: "Mapping ##{i + 1} needs 'match' or 'source'" }, status: :unprocessable_entity
          return
        end
      end
    rescue JSON::ParserError => e
      render json: { success: false, error: "Invalid JSON: #{e.message}" }, status: :unprocessable_entity
      return
    end

    patch = { "hooks" => { "mappings" => parsed } }
    result = gateway_client.config_patch(raw: patch.to_json, reason: "Webhook mappings updated from ClawTrol")

    if result["error"].present?
      render json: { success: false, error: result["error"] }
    else
      render json: { success: true, message: "Webhook mappings saved. Gateway restarting..." }
    end
  end

  # POST /webhooks/mappings/preview
  def preview
    mapping_json = params[:mapping_json].to_s.strip
    begin
      parsed = JSON.parse(mapping_json)
      render json: {
        success: true,
        preview: JSON.pretty_generate(parsed),
        valid: true
      }
    rescue JSON::ParserError => e
      render json: {
        success: false,
        error: e.message,
        valid: false
      }
    end
  end

  private

  def extract_mappings(config)
    return [] unless config.is_a?(Hash) && config["error"].blank?

    raw = config.dig("config") || config
    hooks = raw["hooks"]
    return [] unless hooks.is_a?(Hash)

    mappings = hooks["mappings"]
    return [] unless mappings.is_a?(Array)

    mappings.map.with_index do |m, i|
      {
        index: i,
        match: m["match"] || {},
        source: m["source"],
        action: m["action"] || m["type"] || "wake",
        template: m["template"],
        transform: m["transform"],
        delivery: m["delivery"],
        name: m["name"] || m["label"] || "Mapping ##{i + 1}",
        enabled: m.fetch("enabled", true)
      }
    end
  end

  def mapping_presets
    # NOTE: Use single-quoted strings to avoid Ruby interpolating {{ }}
    [
      {
        name: "GitHub Push",
        description: "Wake agent on GitHub push events",
        mapping: {
          name: "GitHub Push",
          match: { "headers" => { "x-github-event" => "push" } },
          action: "wake",
          template: 'GitHub push to {{body.repository.full_name}} branch {{body.ref}} by {{body.pusher.name}}: {{body.head_commit.message}}'
        }
      },
      {
        name: "GitHub Issue",
        description: "Create task from GitHub issues",
        mapping: {
          name: "GitHub Issue",
          match: { "headers" => { "x-github-event" => "issues" }, "body" => { "action" => "opened" } },
          action: "agent",
          template: 'New GitHub issue #{{body.issue.number}} in {{body.repository.full_name}}: {{body.issue.title}} — {{body.issue.body}}'
        }
      },
      {
        name: "n8n Workflow",
        description: "Receive n8n webhook triggers",
        mapping: {
          name: "n8n Workflow",
          match: { "headers" => { "x-n8n-webhook" => "*" } },
          action: "wake",
          template: 'n8n workflow trigger: {{body.workflowName}} — {{body.message}}'
        }
      },
      {
        name: "Custom JSON",
        description: "Match any POST with custom field",
        mapping: {
          name: "Custom Hook",
          match: { "body" => { "type" => "custom" } },
          action: "wake",
          template: 'Custom webhook: {{body.message}}'
        }
      }
    ]
  end
end
