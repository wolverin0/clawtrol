import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "model", "apiMode", "customKeyWrap", "templatePicker", "soulArea"]
  static values = { providerModels: Object }

  connect() {
    this.templates = this.readTemplates()
    this.fleetTemplates = this.readFleetTemplates()
    this.apiModeChanged()
    // providerModelsValueChanged fires automatically when value is ready
    // but call providerChanged here too as fallback
    if (Object.keys(this.providerModelsValue || {}).length > 0) {
      this.providerChanged()
    }
  }

  // Stimulus calls this automatically when providerModelsValue is set/updated
  providerModelsValueChanged() {
    this.providerChanged()
  }

  providerChanged() {
    const provider = this.providerTarget.value
    const models = this.providerModelsValue?.[provider] || []

    if (this.hasModelTarget) {
      const sel = this.modelTarget
      const current = sel.value
      sel.innerHTML = models.length > 0
        ? models.map((m) => `<option value="${this.escapeHtml(m)}">${this.escapeHtml(m)}</option>`).join("")
        : `<option value="">— no models configured —</option>`
      // Restore previous selection if still valid, else pick first
      if (models.includes(current)) {
        sel.value = current
      } else if (models.length > 0) {
        sel.value = models[0]
      }
    }
  }

  apiModeChanged() {
    const isCustom = this.apiModeTarget.value === "custom"
    this.customKeyWrapTarget.classList.toggle("hidden", !isCustom)
  }

  applyTemplate() {
    const templateId = this.templatePickerTarget.value
    if (!templateId) return

    // Fill SOUL from soul templates
    const soulTemplate = this.templates.find((item) => item.id === templateId)
    if (soulTemplate) {
      this.soulAreaTarget.value = soulTemplate.content || ""
    }

    // Fill all other fields from fleet templates
    const fleet = this.fleetTemplates.find((item) => item.id === templateId)
    if (!fleet) return

    const form = this.element.querySelector("form") || this.element.closest("form")
    if (!form) return

    const setField = (name, value) => {
      const el = form.querySelector(`[name="${name}"]`)
      if (el && value != null) el.value = value
    }

    setField("name", fleet.id)
    setField("emoji", fleet.emoji)
    setField("role", fleet.role)
    setField("mode", fleet.mode)
    setField("model", fleet.suggested_model)
    setField("autonomy", fleet.autonomy)

    // Fill AGENTS.md
    const agentsArea = form.querySelector("[name='agents_content']")
    if (agentsArea && fleet.agents_content) agentsArea.value = fleet.agents_content

    // Set allowed commands checkboxes
    const checkboxes = form.querySelectorAll("[name='allowed_commands[]']")
    const allowed = fleet.allowed_commands || []
    checkboxes.forEach(cb => { cb.checked = allowed.includes(cb.value) })
  }

  readTemplates() {
    const node = document.getElementById("zerobitch-soul-templates")
    if (!node) return []
    try { return JSON.parse(node.textContent) } catch (_) { return [] }
  }

  readFleetTemplates() {
    const node = document.getElementById("zerobitch-fleet-templates")
    if (!node) return []
    try { return JSON.parse(node.textContent) } catch (_) { return [] }
  }

  escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }
}
