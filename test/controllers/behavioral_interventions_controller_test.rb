# frozen_string_literal: true

require "test_helper"

class BehavioralInterventionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # --- Authentication ---

  test "create requires authentication" do
    sign_out
    post behavioral_interventions_path, params: { behavioral_intervention: { rule: "test", category: "qa" } }
    assert_response :redirect
    refute_includes response.location, "interventions"
  end

  # --- Create ---

  test "create with valid params" do
    assert_difference "BehavioralIntervention.count", 1 do
      post behavioral_interventions_path, params: {
        behavioral_intervention: {
          rule: "Never delegate QA",
          category: "qa_delegation",
          status: "active",
          baseline_score: 4.5,
          current_score: 7.0
        }
      }
    end

    assert_redirected_to audits_path(tab: "interventions")
    intervention = BehavioralIntervention.last
    assert_equal "Never delegate QA", intervention.rule
    assert_equal @user.id, intervention.user_id
  end

  test "create with invalid params shows alert" do
    assert_no_difference "BehavioralIntervention.count" do
      post behavioral_interventions_path, params: {
        behavioral_intervention: { rule: "", category: "" }
      }
    end

    assert_redirected_to audits_path(tab: "interventions")
    assert flash[:alert].present?
  end

  # --- Update ---

  test "update own intervention" do
    intervention = BehavioralIntervention.create!(
      user: @user, rule: "Old rule", category: "conciseness", status: "active"
    )

    patch behavioral_intervention_path(intervention), params: {
      behavioral_intervention: { status: "resolved" }
    }

    assert_redirected_to audits_path(tab: "interventions")
    assert_equal "resolved", intervention.reload.status
  end

  test "update with invalid params" do
    intervention = BehavioralIntervention.create!(
      user: @user, rule: "Rule", category: "qa", status: "active"
    )

    patch behavioral_intervention_path(intervention), params: {
      behavioral_intervention: { status: "invalid_status" }
    }

    assert_redirected_to audits_path(tab: "interventions")
    assert flash[:alert].present?
    assert_equal "active", intervention.reload.status
  end

  test "cannot update another users intervention" do
    other_user = users(:two)
    intervention = BehavioralIntervention.create!(
      user: other_user, rule: "Other rule", category: "qa", status: "active"
    )

    patch behavioral_intervention_path(intervention), params: {
      behavioral_intervention: { status: "resolved" }
    }
    assert_response :not_found
    assert_equal "active", intervention.reload.status
  end

  # --- Destroy ---

  test "destroy own intervention" do
    intervention = BehavioralIntervention.create!(
      user: @user, rule: "Delete me", category: "qa", status: "active"
    )

    assert_difference "BehavioralIntervention.count", -1 do
      delete behavioral_intervention_path(intervention)
    end

    assert_redirected_to audits_path(tab: "interventions")
  end

  test "cannot destroy another users intervention" do
    other_user = users(:two)
    intervention = BehavioralIntervention.create!(
      user: other_user, rule: "Not mine", category: "qa", status: "active"
    )

    assert_no_difference "BehavioralIntervention.count" do
      delete behavioral_intervention_path(intervention)
    end
    assert_response :not_found
  end
end
