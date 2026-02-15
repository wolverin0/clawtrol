import { Controller } from "@hotwired/stimulus"

// Canvas / A2UI Push Dashboard controller.
// Manages template selection, HTML editing, preview, and push actions to nodes.
export default class extends Controller {
  static targets = [
    "editor", "previewArea", "previewFrame", "previewToggle",
    "nodeRadio", "manualNode", "width", "height",
    "pushBtn", "snapshotBtn", "hideBtn", "activityLog"
  ]
  static values = { templates: Array }

  connect() {
    this._templateMap = {}
    this.templatesValue.forEach(t => { this._templateMap[t.id] = t })
  }

  // --- Template Selection ---

  selectTemplate(event) {
    const id = event.currentTarget.dataset.templateId
    const tpl = this._templateMap[id]
    if (tpl && this.hasEditorTarget) {
      this.editorTarget.value = tpl.html
      this._log(`Loaded template: ${tpl.name}`)
      this._updatePreview()
    }
  }

  // --- Preview ---

  togglePreview() {
    if (!this.hasPreviewAreaTarget) return
    const hidden = this.previewAreaTarget.classList.toggle("hidden")
    if (!hidden) this._updatePreview()
  }

  _updatePreview() {
    if (!this.hasPreviewFrameTarget || !this.hasEditorTarget) return
    // Use DOMPurify-like approach: strip script tags before preview
    const html = this.editorTarget.value
    const sanitized = html.replace(/<script[\s\S]*?<\/script>/gi, "")
    this.previewFrameTarget.innerHTML = sanitized
  }

  clearEditor() {
    if (this.hasEditorTarget) {
      this.editorTarget.value = ""
      this._log("Editor cleared")
    }
    if (this.hasPreviewFrameTarget) {
      this.previewFrameTarget.innerHTML = ""
    }
  }

  // --- Node Selection ---

  selectNode() {
    // Clear manual input when radio selected
    if (this.hasManualNodeTarget) this.manualNodeTarget.value = ""
  }

  _getSelectedNode() {
    // Manual node takes priority
    if (this.hasManualNodeTarget && this.manualNodeTarget.value.trim()) {
      return this.manualNodeTarget.value.trim()
    }
    // Otherwise check radios
    if (this.hasNodeRadioTarget) {
      const checked = this.nodeRadioTargets.find(r => r.checked)
      if (checked) return checked.value
    }
    return null
  }

  // --- Actions ---

  async pushToNode() {
    const nodeId = this._getSelectedNode()
    if (!nodeId) { this._log("⚠️ Select a target node first"); return }

    const html = this.hasEditorTarget ? this.editorTarget.value.trim() : ""
    if (!html) { this._log("⚠️ HTML content is empty"); return }

    const body = { node_id: nodeId, html_content: html }
    if (this.hasWidthTarget && this.widthTarget.value) body.width = parseInt(this.widthTarget.value)
    if (this.hasHeightTarget && this.heightTarget.value) body.height = parseInt(this.heightTarget.value)

    this._setLoading(this.pushBtnTarget, true)
    this._log(`🚀 Pushing to ${nodeId}...`)

    try {
      const res = await fetch("/canvas/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify(body)
      })
      const data = await res.json()
      if (data.error) {
        this._log(`❌ Push failed: ${data.error}`)
      } else {
        this._log(`✅ Pushed to ${nodeId} successfully`)
      }
    } catch (e) {
      this._log(`❌ Network error: ${e.message}`)
    } finally {
      this._setLoading(this.pushBtnTarget, false)
    }
  }

  async takeSnapshot() {
    const nodeId = this._getSelectedNode()
    if (!nodeId) { this._log("⚠️ Select a target node first"); return }

    this._setLoading(this.snapshotBtnTarget, true)
    this._log(`📸 Taking snapshot of ${nodeId}...`)

    try {
      const res = await fetch("/canvas/snapshot", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ node_id: nodeId })
      })
      const data = await res.json()
      if (data.error) {
        this._log(`❌ Snapshot failed: ${data.error}`)
      } else {
        this._log(`✅ Snapshot captured`)
      }
    } catch (e) {
      this._log(`❌ Network error: ${e.message}`)
    } finally {
      this._setLoading(this.snapshotBtnTarget, false)
    }
  }

  async hideCanvas() {
    const nodeId = this._getSelectedNode()
    if (!nodeId) { this._log("⚠️ Select a target node first"); return }

    this._setLoading(this.hideBtnTarget, true)
    this._log(`🙈 Hiding canvas on ${nodeId}...`)

    try {
      const res = await fetch("/canvas/hide", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrfToken()
        },
        body: JSON.stringify({ node_id: nodeId })
      })
      const data = await res.json()
      if (data.error) {
        this._log(`❌ Hide failed: ${data.error}`)
      } else {
        this._log(`✅ Canvas hidden on ${nodeId}`)
      }
    } catch (e) {
      this._log(`❌ Network error: ${e.message}`)
    } finally {
      this._setLoading(this.hideBtnTarget, false)
    }
  }

  // --- Helpers ---

  _log(msg) {
    if (!this.hasActivityLogTarget) return
    const time = new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit" })
    const entry = document.createElement("div")
    entry.textContent = `[${time}] ${msg}`
    // Remove "no activity" placeholder
    const placeholder = this.activityLogTarget.querySelector(".text-center")
    if (placeholder) placeholder.remove()
    this.activityLogTarget.prepend(entry)
    // Keep max 50 entries
    while (this.activityLogTarget.children.length > 50) {
      this.activityLogTarget.lastElementChild.remove()
    }
  }

  _setLoading(btn, loading) {
    if (!btn) return
    btn.disabled = loading
    if (loading) {
      btn.dataset.origText = btn.textContent
      btn.textContent = "⏳ Working..."
    } else if (btn.dataset.origText) {
      btn.textContent = btn.dataset.origText
    }
  }

  _csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
