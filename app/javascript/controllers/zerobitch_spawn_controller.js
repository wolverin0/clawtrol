import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "modelList", "apiMode", "customKeyWrap", "templatePicker", "soulArea"]
  static values = { providerModels: Object }

  connect() {
    this.templates = this.readTemplates()
    this.fleetTemplates = this.readFleetTemplates()
    this.providerChanged()
    this.apiModeChanged()
  }

  providerChanged() {
    const provider = this.providerTarget.value
    const models = this.providerModelsValue?.[provider] || []

    this.modelListTarget.innerHTML = models
      .map((model) => `<option value="${this.escapeHtml(model)}"></option>`)
      .join("")
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
