require 'dotenv'
require 'httparty'

class SwarmController < ApplicationController
  def index
    @sessions = []
    @error = nil

    # Load environment variables from ~/.openclaw/.env
    begin
      Dotenv.load(File.expand_path('~/.openclaw/.env'))
    rescue Errno::EACCES => e
      @error = "Could not read gateway credentials. Please check file permissions for ~/.openclaw/.env."
      return
    rescue => e
      # Silently ignore if file doesn't exist, token might be in ENV
    end

    gateway_token = ENV['OPENCLAW_GATEWAY_TOKEN']
    gateway_url = ENV['OPENCLAW_GATEWAY_URL'] || 'http://localhost:4818'

    if gateway_token.blank?
      @error = "OPENCLAW_GATEWAY_TOKEN not found. Please set it in your environment or in ~/.openclaw/.env."
      return
    end

    begin
      api_url = "#{gateway_url}/api/sessions?activeMinutes=60"
      response = HTTParty.get(api_url, {
        headers: { "Authorization" => "Bearer #{gateway_token}" },
        timeout: 5 # Set a reasonable timeout
      })

      if response.success?
        @sessions = response.parsed_response
      else
        @error = "Gateway API returned status #{response.code}: #{response.message}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      @error = "Gateway is unreachable (timeout). Is it running at #{gateway_url}?"
    rescue Errno::ECONNREFUSED => e
      @error = "Gateway connection refused. Is it running at #{gateway_url}?"
    rescue StandardError => e
      @error = "An unexpected error occurred: #{e.message}"
    end
  end
end
