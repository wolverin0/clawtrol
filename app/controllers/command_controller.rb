class CommandController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json do
        begin
          data = fetch_gateway_data
          render json: data
        rescue StandardError => e
          render json: { error: e.message, status: "offline" }, status: :service_unavailable
        end
      end
    end
  end

  private

  def fetch_gateway_data
    # 1. Get Token
    token = ENV['OPENCLAW_GATEWAY_TOKEN'] || ENV['CLAWTROL_GATEWAY_TOKEN'] || fetch_token_from_env_file

    # 2. Setup Request
    uri = URI("http://localhost:4818/api/sessions?activeMinutes=120&messageLimit=1")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"

    # 3. Fetch
    res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 3) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    else
      { error: "Gateway returned #{res.code}", status: "error" }
    end
  rescue Errno::ECONNREFUSED
    { error: "Connection refused", status: "offline" }
  end

  def fetch_token_from_env_file
    env_path = File.expand_path("~/.openclaw/.env")
    return nil unless File.exist?(env_path)

    token = nil
    File.foreach(env_path) do |line|
      if line =~ /^(?:OPENCLAW|CLAWTROL)_GATEWAY_TOKEN=(.+)$/
        token = $1.strip.gsub(/["']/, '') # Remove quotes if present
        break if line.start_with?('OPENCLAW_') # Prefer OPENCLAW prefix if both exist
      end
    end
    token
  end
end
