module Api
  module V1
    class AgentPersonasController < BaseController
      before_action :set_agent_persona, only: [:show, :update, :destroy]

      # GET /api/v1/agent_personas
      def index
        personas = AgentPersona.for_user(current_user)
                               .order(active: :desc, tier: :asc, name: :asc)

        # Filter by tier
        personas = personas.by_tier(params[:tier]) if params[:tier].present?
        
        # Filter by project
        personas = personas.by_project(params[:project]) if params[:project].present?
        
        # Filter active only
        personas = personas.active if params[:active] == 'true'

        render json: personas.map { |p| persona_json(p) }
      end

      # GET /api/v1/agent_personas/:id
      def show
        render json: persona_json(@agent_persona, full: true)
      end

      # POST /api/v1/agent_personas
      def create
        persona = current_user.agent_personas.build(agent_persona_params)
        
        if persona.save
          render json: persona_json(persona, full: true), status: :created
        else
          render json: { error: persona.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/agent_personas/:id
      def update
        if @agent_persona.update(agent_persona_params)
          render json: persona_json(@agent_persona, full: true)
        else
          render json: { error: @agent_persona.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/agent_personas/:id
      def destroy
        @agent_persona.destroy
        render json: { success: true }
      end

      # POST /api/v1/agent_personas/import
      def import
        personas_dir = params[:directory] || File.expand_path("~/.openclaw/workspace/docs/agent-personas")
        
        unless Dir.exist?(personas_dir)
          render json: { error: "Directory not found: #{personas_dir}" }, status: :not_found
          return
        end

        imported = AgentPersona.import_from_directory(personas_dir, user: current_user)
        
        render json: {
          imported: imported.count,
          personas: imported.map { |p| persona_json(p) }
        }
      end

      private

      def set_agent_persona
        @agent_persona = AgentPersona.for_user(current_user).find(params[:id])
      end

      def agent_persona_params
        params.permit(
          :name, :role, :description, :model, :fallback_model,
          :tier, :project, :emoji, :system_prompt, :active,
          tools: []
        )
      end

      def persona_json(persona, full: false)
        json = {
          id: persona.id,
          name: persona.name,
          emoji: persona.emoji,
          description: persona.description,
          model: persona.model,
          fallback_model: persona.fallback_model,
          model_chain: persona.model_chain,
          tier: persona.tier,
          project: persona.project,
          tools: persona.tools_list,
          active: persona.active,
          created_at: persona.created_at,
          updated_at: persona.updated_at
        }

        if full
          json[:role] = persona.role
          json[:system_prompt] = persona.system_prompt
          json[:spawn_prompt] = persona.spawn_prompt
        end

        json
      end
    end
  end
end
