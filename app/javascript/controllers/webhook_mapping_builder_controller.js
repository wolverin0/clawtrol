import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for the Webhook Mapping Builder.
 * Manages CRUD operations on mappings and saves to gateway config.
 */
export default class extends Controller {
  static targets = ["mappingsList", "jsonPreview", "status", "count",
                     "editModal", "editName", "editAction", "editMatch",
                     "editTemplate", "editTransform", "emptyState"]

  connect() {
    this.mappings = this.loadMappingsFromDOM()
    this.editingIndex = -1
    this.updatePreview()
  }

  loadMappingsFromDOM() {
    const items = this.mappingsListTarget.querySelectorAll("[data-mapping-json]")
    return Array.from(items).map(el => {
      try {
        return JSON.parse(el.dataset.mappingJson)
      } catch {
        return null
      }
    }).filter(Boolean)
  }

  addMapping() {
    this.editingIndex = -1
    this.clearEditForm()
    this.editNameTarget.value = "New Mapping"
    this.editActionTarget.value = "wake"
    this.editMatchTarget.value = '{\n  "headers": {},\n  "body": {}\n}'
    this.editTemplateTarget.value = ""
    this.editTransformTarget.value = ""
    this.showModal()
  }

  loadPreset(event) {
    const presetJson = event.currentTarget.dataset.presetJson
    try {
      const preset = JSON.parse(presetJson)
      this.editingIndex = -1
      this.editNameTarget.value = preset.name || "Preset"
      this.editActionTarget.value = preset.action || "wake"
      this.editMatchTarget.value = JSON.stringify(preset.match || {}, null, 2)
      this.editTemplateTarget.value = preset.template || ""
      this.editTransformTarget.value = preset.transform || ""
      this.showModal()
    } catch (err) {
      this.showStatus(`Invalid preset: ${err.message}`, "error")
    }
  }

  editMapping(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (index < 0 || index >= this.mappings.length) return

    this.editingIndex = index
    const m = this.mappings[index]
    this.editNameTarget.value = m.name || ""
    this.editActionTarget.value = m.action || "wake"
    this.editMatchTarget.value = JSON.stringify(m.match || {}, null, 2)
    this.editTemplateTarget.value = m.template || ""
    this.editTransformTarget.value = m.transform || ""
    this.showModal()
  }

  removeMapping(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (index < 0 || index >= this.mappings.length) return

    if (!confirm(`Remove mapping "${this.mappings[index].name}"?`)) return

    this.mappings.splice(index, 1)
    this.renderMappings()
    this.updatePreview()
  }

  applyEdit() {
    let match
    try {
      match = JSON.parse(this.editMatchTarget.value || "{}")
    } catch (err) {
      this.showStatus(`Invalid match JSON: ${err.message}`, "error")
      return
    }

    const mapping = {
      name: this.editNameTarget.value || "Mapping",
      match: match,
      action: this.editActionTarget.value || "wake",
      template: this.editTemplateTarget.value || undefined,
      transform: this.editTransformTarget.value || undefined,
      enabled: true
    }

    if (this.editingIndex >= 0 && this.editingIndex < this.mappings.length) {
      this.mappings[this.editingIndex] = mapping
    } else {
      this.mappings.push(mapping)
    }

    this.closeModal()
    this.renderMappings()
    this.updatePreview()
  }

  async saveAll() {
    // Clean mappings for output (remove index, keep only relevant fields)
    const cleanMappings = this.mappings.map(m => {
      const clean = { name: m.name, match: m.match, action: m.action, enabled: m.enabled !== false }
      if (m.template) clean.template = m.template
      if (m.transform) clean.transform = m.transform
      if (m.delivery) clean.delivery = m.delivery
      if (m.source) clean.source = m.source
      return clean
    })

    this.showStatus("Saving mappings to gateway...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/webhooks/mappings/save", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ mappings_json: JSON.stringify(cleanMappings) })
      })

      const data = await response.json()
      if (data.success) {
        this.showStatus(data.message || "Saved!", "success")
      } else {
        this.showStatus(data.error || "Save failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  copyJson() {
    const text = this.jsonPreviewTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.showStatus("Copied to clipboard!", "success")
    }).catch(() => {
      this.showStatus("Copy failed", "error")
    })
  }

  showModal() {
    this.editModalTarget.classList.remove("hidden")
    this.editNameTarget.focus()
  }

  closeModal() {
    this.editModalTarget.classList.add("hidden")
    this.editingIndex = -1
  }

  clearEditForm() {
    this.editNameTarget.value = ""
    this.editActionTarget.value = "wake"
    this.editMatchTarget.value = "{}"
    this.editTemplateTarget.value = ""
    this.editTransformTarget.value = ""
  }

  renderMappings() {
    const list = this.mappingsListTarget
    list.innerHTML = ""

    if (this.mappings.length === 0) {
      list.innerHTML = `
        <div class="bg-bg-surface rounded-lg border border-border p-8 text-center">
          <span class="text-3xl">🪝</span>
          <p class="text-sm text-content-muted mt-2">No webhook mappings configured.</p>
        </div>`
      return
    }

    this.mappings.forEach((m, i) => {
      const matchStr = JSON.stringify(m.match || {}, null, 2)
      const div = document.createElement("div")
      div.className = "bg-bg-surface rounded-lg border border-border overflow-hidden"
      div.innerHTML = `
        <div class="px-4 py-3 bg-bg-elevated border-b border-border flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="text-sm">${m.enabled !== false ? '🟢' : '🔴'}</span>
            <span class="text-sm font-semibold text-content">${this.escapeHtml(m.name || 'Mapping')}</span>
            <span class="text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded-full">${this.escapeHtml(m.action || 'wake')}</span>
          </div>
          <div class="flex items-center gap-1">
            <button type="button" data-action="click->webhook-mapping-builder#editMapping" data-index="${i}"
                    class="p-1 text-content-muted hover:text-content transition-colors" title="Edit">✏️</button>
            <button type="button" data-action="click->webhook-mapping-builder#removeMapping" data-index="${i}"
                    class="p-1 text-content-muted hover:text-red-400 transition-colors" title="Remove">🗑️</button>
          </div>
        </div>
        <div class="p-4 grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
          <div>
            <label class="font-medium text-content-muted block mb-1">Match Rules</label>
            <pre class="bg-bg-base rounded px-2 py-1.5 border border-border text-content font-mono overflow-x-auto">${this.escapeHtml(matchStr)}</pre>
          </div>
          <div>
            <label class="font-medium text-content-muted block mb-1">Template</label>
            <div class="bg-bg-base rounded px-2 py-1.5 border border-border text-content font-mono whitespace-pre-wrap">${this.escapeHtml(m.template || '(no template)')}</div>
          </div>
        </div>`
      list.appendChild(div)
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.mappings.length} mapping${this.mappings.length === 1 ? '' : 's'}`
    }
  }

  updatePreview() {
    const cleanMappings = this.mappings.map(m => {
      const clean = { name: m.name, match: m.match, action: m.action }
      if (m.template) clean.template = m.template
      if (m.transform) clean.transform = m.transform
      return clean
    })
    this.jsonPreviewTarget.textContent = JSON.stringify(cleanMappings, null, 2)
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = message
    el.classList.remove("hidden", "bg-green-500/20", "text-green-400",
                        "bg-red-500/20", "text-red-400", "bg-blue-500/20", "text-blue-400")
    if (type === "success") el.classList.add("bg-green-500/20", "text-green-400")
    else if (type === "error") el.classList.add("bg-red-500/20", "text-red-400")
    else el.classList.add("bg-blue-500/20", "text-blue-400")
    el.classList.remove("hidden")
    if (type !== "error") setTimeout(() => el.classList.add("hidden"), 5000)
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
