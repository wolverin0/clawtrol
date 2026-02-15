# frozen_string_literal: true

class NodesController < ApplicationController
  include GatewayClientAccessible
  before_action :require_authentication

  # GET /nodes
  def index
    @nodes_data = Rails.cache.fetch("nodes/status/#{current_user.id}", expires_in: 15.seconds) do
      gateway_client.nodes_status
    end
    @nodes = Array(@nodes_data["nodes"] || @nodes_data[:nodes])
    @error = @nodes_data["error"]
  end
end
