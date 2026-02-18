# frozen_string_literal: true

class ZeroclawAgent < ApplicationRecord
  validates :name, presence: true
  validates :url, presence: true

  scope :active, -> { where(status: "active") }

  # Returns the next available agent (health-checked) using round-robin order
  def self.next_available
    active.order(:last_seen_at).each do |agent|
      return agent if agent.healthy?
    end
    nil
  end

  def healthy?
    uri = URI("#{url}/health")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  def dispatch(message)
    uri = URI("#{url}/webhook")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 10
    http.read_timeout = 60
    request = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/json" })
    request.body = JSON.generate({ message: message })
    response = http.request(request)
    raise "ZeroClaw dispatch failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
