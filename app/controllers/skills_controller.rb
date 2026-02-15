# frozen_string_literal: true

class SkillsController < ApplicationController
  before_action :require_authentication

  # GET /skills
  def index
    @skills = SkillScannerService.call
    @bundled_count = @skills.count { |s| s.source == "bundled" }
    @workspace_count = @skills.count { |s| s.source == "workspace" }
  end
end
