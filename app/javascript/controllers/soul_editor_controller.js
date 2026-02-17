import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "textarea", "charCount", "lastModified", "saveBtn", "fileTab", "dirtyDot",
    "unsavedLabel", "templatesPanel", "historyPanel", "sidebarTab", "previewBadge", "statusText"
  ]

  static values = {
    activeFile: String
  }

  connect() {
    this.savedContent = this.textareaTarget.value || ""
    this.previewMode = false
    this.sidebar = "templates"

    this.updateUi()
    this.highlightActiveFile()
    this.highlightSidebarTab()
    this.loadTemplates()
    this.loadHistory()

    this.boundKeydown = this.handleGlobalKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown)
  }

  onInput() {
    if (this.previewMode) return
    this.updateUi()
  }

  onKeyDown(event) {
    if (event.key === "Tab") {
      event.preventDefault()
      const start = this.textareaTarget.selectionStart
      const end = this.textareaTarget.selectionEnd
      const value = this.textareaTarget.value
      this.textareaTarget.value = `${value.slice(0, start)}  ${value.slice(end)}`
      this.textareaTarget.selectionStart = this.textareaTarget.selectionEnd = start + 2
      this.updateUi()
    }
  }

  handleGlobalKeydown(event) {
    const isSave = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s"
    if (!isSave) return

    event.preventDefault()
    this.save()
  }

  async switchFile(event) {
    const nextFile = event.currentTarget.dataset.file
    if (!nextFile || nextFile === this.activeFileValue) return

    if (this.isDirty() && !window.confirm("You have unsaved changes. Switch file anyway?")) {
      return
    }

    await this.fetchFile(nextFile)
  }

  async switchSidebar(event) {
    this.sidebar = event.currentTarget.dataset.tab || "templates"
    this.highlightSidebarTab()
    this.templatesPanelTarget.classList.toggle("hidden", this.sidebar !== "templates")
    this.historyPanelTarget.classList.toggle("hidden", this.sidebar !== "history")

    if (this.sidebar === "templates") {
      await this.loadTemplates()
    } else {
      await this.loadHistory()
    }
  }

  async save() {
    if (this.previewMode) {
      this.exitPreview()
    }

    this.showStatus("Saving...")
    this.saveBtnTarget.disabled = true

    try {
      const response = await this.request("/soul-editor", {
        method: "PATCH",
        body: JSON.stringify({ file: this.activeFileValue, content: this.textareaTarget.value })
      })

      if (!response.success) throw new Error(response.error || "Save failed")

      this.savedContent = this.textareaTarget.value
      this.lastModifiedTarget.textContent = this.relativeTime(response.last_modified)
      this.showStatus("Saved ✅")
      this.flashSaveButton()
      this.updateUi()
      await this.loadHistory()
    } catch (error) {
      this.showStatus(`Error: ${error.message}`)
    } finally {
      this.saveBtnTarget.disabled = false
    }
  }

  async reset() {
    if (this.isDirty() && !window.confirm("Discard unsaved changes and reload from disk?")) return
    await this.fetchFile(this.activeFileValue)
  }

  async useTemplate(event) {
    const content = event.currentTarget.dataset.content || ""
    this.enterPreview(content)
  }

  applyTemplate(event) {
    const content = event.currentTarget.dataset.content || ""
    this.exitPreview(false)
    this.textareaTarget.value = content
    this.textareaTarget.readOnly = false
    this.showStatus("Template applied")
    this.updateUi()
  }

  async previewHistory(event) {
    const content = event.currentTarget.dataset.content || ""
    this.enterPreview(content)
  }

  async revert(event) {
    const timestamp = event.currentTarget.dataset.timestamp
    if (!timestamp) return
    if (!window.confirm("Revert to this version?")) return

    this.showStatus("Reverting...")

    try {
      const response = await this.request("/soul-editor/revert", {
        method: "POST",
        body: JSON.stringify({ file: this.activeFileValue, timestamp })
      })

      if (!response.success) throw new Error(response.error || "Revert failed")

      this.textareaTarget.value = response.content || ""
      this.savedContent = this.textareaTarget.value
      this.lastModifiedTarget.textContent = this.relativeTime(response.last_modified)
      this.exitPreview(false)
      this.showStatus("Reverted ✅")
      this.updateUi()
      await this.loadHistory()
    } catch (error) {
      this.showStatus(`Error: ${error.message}`)
    }
  }

  async fetchFile(fileName) {
    this.showStatus(`Loading ${fileName}...`)

    const response = await this.request(`/soul-editor?file=${encodeURIComponent(fileName)}`, { method: "GET" })
    if (!response.success) throw new Error(response.error || "Failed to load file")

    this.activeFileValue = response.file
    this.textareaTarget.value = response.content || ""
    this.savedContent = this.textareaTarget.value
    this.lastModifiedTarget.textContent = this.relativeTime(response.last_modified)
    this.exitPreview(false)
    this.updateUi()
    this.highlightActiveFile()

    await this.loadTemplates()
    await this.loadHistory()
  }

  async loadTemplates() {
    const response = await this.request(`/soul-editor/templates?file=${encodeURIComponent(this.activeFileValue)}`, { method: "GET" })
    const templates = response.templates || []

    if (this.activeFileValue !== "SOUL.md") {
      this.templatesPanelTarget.innerHTML = `<div class="text-xs text-content-muted">Templates are available only for SOUL.md</div>`
      return
    }

    this.templatesPanelTarget.innerHTML = templates.map((tpl) => `
      <div class="border border-border rounded-lg p-3 bg-bg-base/50">
        <div class="text-sm font-medium text-content">${this.escapeHtml(tpl.name)}</div>
        <div class="text-xs text-content-muted mt-1">${this.escapeHtml(tpl.description || "")}</div>
        <div class="mt-2 flex gap-2">
          <button type="button" class="text-xs px-2 py-1 rounded border border-border text-content-muted hover:text-content"
                  data-action="click->soul-editor#useTemplate"
                  data-content="${this.escapeAttr(tpl.content || "")}">
            Preview
          </button>
          <button type="button" class="text-xs px-2 py-1 rounded bg-accent text-white"
                  data-action="click->soul-editor#applyTemplate"
                  data-content="${this.escapeAttr(tpl.content || "")}">
            Use Template
          </button>
        </div>
      </div>
    `).join("")
  }

  async loadHistory() {
    const response = await this.request(`/soul-editor/history?file=${encodeURIComponent(this.activeFileValue)}`, { method: "GET" })
    const history = (response.history || []).slice().reverse()

    if (history.length === 0) {
      this.historyPanelTarget.innerHTML = `<div class="text-xs text-content-muted">No history yet.</div>`
      return
    }

    this.historyPanelTarget.innerHTML = history.map((entry) => `
      <div class="border border-border rounded-lg p-3 bg-bg-base/50 group">
        <div class="text-xs text-content-muted">${this.relativeTime(entry.timestamp)}</div>
        <div class="mt-2 flex gap-2 opacity-80 group-hover:opacity-100 transition-opacity">
          <button type="button" class="text-xs px-2 py-1 rounded border border-border text-content-muted hover:text-content"
                  data-action="click->soul-editor#previewHistory"
                  data-content="${this.escapeAttr(entry.content || "")}">
            Preview
          </button>
          <button type="button" class="text-xs px-2 py-1 rounded bg-yellow-600/80 hover:bg-yellow-500 text-white"
                  data-action="click->soul-editor#revert"
                  data-timestamp="${this.escapeAttr(entry.timestamp)}">
            Revert
          </button>
        </div>
      </div>
    `).join("")
  }

  updateUi() {
    this.charCountTarget.textContent = String((this.textareaTarget.value || "").length)
    const dirty = this.isDirty()
    this.unsavedLabelTarget.classList.toggle("hidden", !dirty)
    this.dirtyDotTargets.forEach((dot) => {
      const isActive = dot.dataset.file === this.activeFileValue
      dot.classList.toggle("hidden", !(isActive && dirty))
    })
  }

  highlightActiveFile() {
    this.fileTabTargets.forEach((tab) => {
      const active = tab.dataset.file === this.activeFileValue
      tab.classList.toggle("bg-bg-base", active)
      tab.classList.toggle("text-content", active)
      tab.classList.toggle("border-border", active)
      tab.classList.toggle("text-content-muted", !active)
    })
  }

  highlightSidebarTab() {
    this.sidebarTabTargets.forEach((tab) => {
      const active = tab.dataset.tab === this.sidebar
      tab.classList.toggle("bg-bg-surface", active)
      tab.classList.toggle("text-content", active)
      tab.classList.toggle("text-content-muted", !active)
    })
  }

  enterPreview(content) {
    this.previewMode = true
    this.textareaTarget.value = content
    this.textareaTarget.readOnly = true
    this.previewBadgeTarget.classList.remove("hidden")
    this.showStatus("Preview mode")
    this.updateUi()
  }

  exitPreview(restoreSaved = false) {
    if (!this.previewMode) return
    if (restoreSaved) {
      this.textareaTarget.value = this.savedContent
    }
    this.previewMode = false
    this.textareaTarget.readOnly = false
    this.previewBadgeTarget.classList.add("hidden")
    this.updateUi()
  }

  isDirty() {
    return (this.textareaTarget.value || "") !== (this.savedContent || "")
  }

  showStatus(text) {
    this.statusTextTarget.textContent = text
  }

  flashSaveButton() {
    this.saveBtnTarget.classList.add("ring-2", "ring-emerald-300")
    setTimeout(() => this.saveBtnTarget.classList.remove("ring-2", "ring-emerald-300"), 600)
  }

  relativeTime(isoTime) {
    if (!isoTime) return "-"
    const then = new Date(isoTime)
    if (Number.isNaN(then.getTime())) return "-"

    const delta = Math.max(1, Math.floor((Date.now() - then.getTime()) / 1000))
    if (delta < 60) return `${delta}s ago`
    if (delta < 3600) return `${Math.floor(delta / 60)}m ago`
    if (delta < 86_400) return `${Math.floor(delta / 3600)}h ago`
    return `${Math.floor(delta / 86_400)}d ago`
  }

  async request(url, options = {}) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method: options.method || "GET",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: options.body
    })

    const data = await response.json()
    if (!response.ok) {
      throw new Error(data.error || `HTTP ${response.status}`)
    }

    return data
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }

  escapeAttr(value) {
    return this.escapeHtml(value).replaceAll("`", "&#096;")
  }
}
