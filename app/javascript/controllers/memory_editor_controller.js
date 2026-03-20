import { Controller } from "@hotwired/stimulus"

// Inline memory file editor with Cmd+S save
// Renders a monospace textarea for markdown editing
export default class extends Controller {
  static targets = ["viewer", "editor", "textarea", "editBtn", "saveBtn", "cancelBtn", "dirtyDot"]
  static values = { filePath: String }

  connect() {
    this._keyHandler = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this._keyHandler)
    this.dirty = false
  }

  disconnect() {
    document.removeEventListener("keydown", this._keyHandler)
  }

  async edit() {
    if (!this.filePathValue) return

    this.editBtnTarget.textContent = "⏳ Loading..."
    this.editBtnTarget.disabled = true

    try {
      const res = await fetch(`/view?file=${encodeURIComponent(this.filePathValue)}&format=raw`)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const content = await res.text()

      this.originalContent = content
      this.textareaTarget.value = content
      this.dirty = false
      this._updateUI(true)
      this.textareaTarget.focus()
    } catch (e) {
      alert(`Failed to load: ${e.message}`)
      this.editBtnTarget.textContent = "✏️ Edit"
      this.editBtnTarget.disabled = false
    }
  }

  async save() {
    if (!this.dirty) return

    this.saveBtnTarget.textContent = "⏳ Saving..."
    this.saveBtnTarget.disabled = true

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const res = await fetch(`/view?file=${encodeURIComponent(this.filePathValue)}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify({ file: this.filePathValue, content: this.textareaTarget.value })
      })

      const data = await res.json()
      if (data.ok) {
        this.dirty = false
        this._updateUI(false)
        // Reload the viewer content
        window.location.reload()
      } else {
        throw new Error(data.error || "Unknown error")
      }
    } catch (e) {
      alert(`Save failed: ${e.message}`)
      this.saveBtnTarget.textContent = "💾 Save"
      this.saveBtnTarget.disabled = false
    }
  }

  cancel() {
    if (this.dirty && !confirm("Discard unsaved changes?")) return
    this.dirty = false
    this._updateUI(false)
  }

  markDirty() {
    this.dirty = this.textareaTarget.value !== this.originalContent
    if (this.hasDirtyDotTarget) {
      this.dirtyDotTarget.classList.toggle("hidden", !this.dirty)
    }
    this.saveBtnTarget.disabled = !this.dirty
    this.saveBtnTarget.style.opacity = this.dirty ? "1" : "0.5"
  }

  _handleKeydown(e) {
    if ((e.ctrlKey || e.metaKey) && e.key === "s") {
      if (this.hasTextareaTarget && !this.textareaTarget.classList.contains("hidden")) {
        e.preventDefault()
        this.save()
      }
    }
  }

  _updateUI(editing) {
    if (this.hasViewerTarget) this.viewerTarget.classList.toggle("hidden", editing)
    if (this.hasEditorTarget) this.editorTarget.classList.toggle("hidden", !editing)
    if (this.hasEditBtnTarget) {
      this.editBtnTarget.classList.toggle("hidden", editing)
      this.editBtnTarget.textContent = "✏️ Edit"
      this.editBtnTarget.disabled = false
    }
    if (this.hasSaveBtnTarget) this.saveBtnTarget.classList.toggle("hidden", !editing)
    if (this.hasCancelBtnTarget) this.cancelBtnTarget.classList.toggle("hidden", !editing)
  }
}
