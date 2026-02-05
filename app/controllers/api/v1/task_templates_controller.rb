module Api
  module V1
    class TaskTemplatesController < BaseController
      before_action :set_template, only: [:show, :update, :destroy]

      # GET /api/v1/task_templates
      def index
        @templates = TaskTemplate.for_user(current_user).ordered
        render json: @templates.map { |t| template_json(t) }
      end

      # GET /api/v1/task_templates/:id
      def show
        render json: template_json(@template)
      end

      # POST /api/v1/task_templates
      def create
        @template = current_user.task_templates.build(template_params)
        
        if @template.save
          render json: template_json(@template), status: :created
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/task_templates/:id
      def update
        if @template.user_id != current_user.id
          render json: { error: "Cannot modify global templates" }, status: :forbidden
          return
        end

        if @template.update(template_params)
          render json: template_json(@template)
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/task_templates/:id
      def destroy
        if @template.global?
          render json: { error: "Cannot delete global templates" }, status: :forbidden
          return
        end

        @template.destroy
        head :no_content
      end

      # POST /api/v1/task_templates/apply
      # Applies a template to return task attributes
      def apply
        slug = params[:slug] || params[:template]
        template = TaskTemplate.find_for_user(slug, current_user)

        if template.nil?
          render json: { error: "Template not found: #{slug}" }, status: :not_found
          return
        end

        task_name = params[:task_name] || params[:name] || ""
        render json: {
          template: template_json(template),
          task_attributes: template.to_task_attributes(task_name)
        }
      end

      private

      def set_template
        @template = TaskTemplate.for_user(current_user).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Template not found" }, status: :not_found
      end

      def template_params
        params.require(:task_template).permit(:name, :slug, :icon, :model, :priority, :validation_command, :description_template)
      end

      def template_json(template)
        {
          id: template.id,
          name: template.name,
          slug: template.slug,
          icon: template.icon,
          display_name: template.display_name,
          model: template.model,
          priority: template.priority,
          validation_command: template.validation_command,
          description_template: template.description_template,
          global: template.global?,
          user_id: template.user_id,
          created_at: template.created_at,
          updated_at: template.updated_at
        }
      end
    end
  end
end
