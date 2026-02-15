class BehavioralInterventionsController < ApplicationController
  before_action :require_authentication

  def create
    @intervention = current_user.behavioral_interventions.build(intervention_params)
    if @intervention.save
      redirect_to audits_path(tab: "interventions"), notice: "Intervention created"
    else
      redirect_to audits_path(tab: "interventions"), alert: @intervention.errors.full_messages.join(", ")
    end
  end

  def update
    @intervention = current_user.behavioral_interventions.find(params[:id])
    if @intervention.update(intervention_params)
      redirect_to audits_path(tab: "interventions"), notice: "Intervention updated"
    else
      redirect_to audits_path(tab: "interventions"), alert: @intervention.errors.full_messages.join(", ")
    end
  end

  def destroy
    @intervention = current_user.behavioral_interventions.find(params[:id])
    @intervention.destroy
    redirect_to audits_path(tab: "interventions"), notice: "Intervention deleted"
  end

  private

  def intervention_params
    params.require(:behavioral_intervention).permit(:rule, :category, :baseline_score, :current_score, :status, :notes, :audit_report_id)
  end
end
