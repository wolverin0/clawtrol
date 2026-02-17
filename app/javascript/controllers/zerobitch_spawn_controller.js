import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "modelList", "apiMode", "customKeyWrap", "templatePicker", "soulArea"]
  static values = { providerModels: Object }

  connect() {
    this.templates = this.readTemplates()
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

    const template = this.templates.find((item) => item.id === templateId)
    if (!template) return

    this.soulAreaTarget.value = template.content || ""
  }

  readTemplates() {
    const node = document.getElementById("zerobitch-soul-templates")
    if (!node) return []

    try {
      return JSON.parse(node.textContent)
    } catch (_error) {
      return []
    }
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
