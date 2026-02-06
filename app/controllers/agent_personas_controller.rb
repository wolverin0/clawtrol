class AgentPersonasController < ApplicationController
  before_action :require_authentication
  before_action :set_agent_persona, only: [:show, :edit, :update, :destroy]

  def roster
    @agent_personas = current_user.agent_personas
                                  .or(AgentPersona.where(user_id: nil))
                                  .where(active: true)
                                  .order(tier: :asc, name: :asc)

    # Filter by tier
    @agent_personas = @agent_personas.by_tier(params[:tier]) if params[:tier].present?

    # Precompute active task counts per persona (tasks with status=in_progress)
    @active_task_counts = Task.where(
      agent_persona_id: @agent_personas.pluck(:id),
      status: :in_progress
    ).group(:agent_persona_id).count

    # Get rate-limited models for the current user
    @rate_limited_models = ModelLimit
      .where(user: current_user, limited: true)
      .where("resets_at > ?", Time.current)
      .pluck(:name)
      .to_set

    # Filter by status if requested
    if params[:status].present?
      @agent_personas = @agent_personas.select do |p|
        count = @active_task_counts[p.id] || 0
        computed = helpers.agent_status(p, count, @rate_limited_models)
        computed.to_s == params[:status]
      end
    end

    # Sort by activity if requested
    if params[:sort] == "activity"
      @agent_personas = @agent_personas.sort_by { |p| -((@active_task_counts[p.id] || 0)) }
    end

    # Summary stats
    all_personas = current_user.agent_personas
                               .or(AgentPersona.where(user_id: nil))
                               .where(active: true)
    all_ids = all_personas.pluck(:id)
    all_counts = Task.where(agent_persona_id: all_ids, status: :in_progress).group(:agent_persona_id).count
    @stats = {
      total: all_personas.count,
      working: all_counts.count { |_id, c| c > 0 },
      rate_limited: all_personas.count { |p| @rate_limited_models.include?(p.model) },
      idle: all_personas.count { |p| (all_counts[p.id] || 0) == 0 && !@rate_limited_models.include?(p.model) },
      total_active_tasks: all_counts.values.sum
    }
  end

  def index
    @agent_personas = current_user.agent_personas
                                  .or(AgentPersona.where(user_id: nil))
                                  .order(active: :desc, tier: :asc, name: :asc)

    # Filter by tier if specified
    @agent_personas = @agent_personas.by_tier(params[:tier]) if params[:tier].present?
    
    # Filter by project if specified
    @agent_personas = @agent_personas.by_project(params[:project]) if params[:project].present?

    # Filter active only
    @agent_personas = @agent_personas.active if params[:active] == 'true'
  end

  def show
  end

  def new
    @agent_persona = current_user.agent_personas.build(
      model: 'sonnet',
      emoji: '🤖',
      active: true
    )
  end

  def create
    @agent_persona = current_user.agent_personas.build(agent_persona_params)
    
    if @agent_persona.save
      redirect_to agent_persona_path(@agent_persona), notice: "Persona created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agent_persona.update(agent_persona_params)
      redirect_to agent_persona_path(@agent_persona), notice: "Persona updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @agent_persona.destroy
    redirect_to agent_personas_path, notice: "Persona deleted."
  end

  def import
    personas_dir = File.expand_path("~/.openclaw/workspace/docs/agent-personas")
    
    unless Dir.exist?(personas_dir)
      redirect_to agent_personas_path, alert: "Personas directory not found: #{personas_dir}"
      return
    end

    imported = AgentPersona.import_from_directory(personas_dir, user: current_user)
    
    if imported.any?
      redirect_to agent_personas_path, notice: "Imported #{imported.count} personas successfully."
    else
      redirect_to agent_personas_path, alert: "No personas found to import."
    end
  end

  private

  def set_agent_persona
    @agent_persona = AgentPersona.for_user(current_user).find(params[:id])
  end

  def agent_persona_params
    params.require(:agent_persona).permit(
      :name, :role, :description, :model, :fallback_model,
      :tier, :project, :emoji, :system_prompt, :active,
      tools: []
    ).tap do |p|
      # Handle tools as comma-separated string from form
      if params[:agent_persona][:tools_string].present?
        p[:tools] = params[:agent_persona][:tools_string].split(/,\s*/).map(&:strip)
      end
    end
  end
end
