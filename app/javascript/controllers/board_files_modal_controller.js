import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "dragHandle", "filename", "content", "saveButton", "error", "fileButton"]
  static values = { boardId: Number }

  connect() {
    this.currentPath = null
    this.dirty = false
    this.initDrag()

    const initialEditor = this.contentTarget.querySelector("textarea[data-role='editor']")
    if (initialEditor) {
      initialEditor.addEventListener("input", () => this.markDirty())
    }
  }

  get baseUrl() {
    return `/boards/${this.boardIdValue}/project_files`
  }

  close(event) {
    if (event) event.preventDefault()
    if (this.dirty && !window.confirm("Tenés cambios sin guardar. ¿Cerrar igual?")) return

    const frame = document.getElementById("board_files_modal")
    if (frame) frame.innerHTML = ""
  }

  initDrag() {
    if (!this.hasDragHandleTarget || !this.hasModalTarget) return
    const win = this.dragHandleTarget
    const modal = this.modalTarget
    if (win._dragInit) return
    win._dragInit = true

    const w = Math.min(1100, window.innerWidth * 0.9)
    const h = Math.min(window.innerHeight * 0.88, 760)
    const left = Math.max(16, (window.innerWidth - w) / 2)
    const top = Math.max(16, (window.innerHeight - h) / 2)
    modal.style.cssText = `position:fixed; inset:auto; left:${left}px; top:${top}px; width:${w}px; height:${h}px; margin:0; padding:0;`

    const handle = win.firstElementChild
    if (!handle) return
    handle.style.cursor = "grab"

    handle.addEventListener("mousedown", (e) => {
      if (e.target.closest("button, a, input, textarea")) return
      e.preventDefault()
      handle.style.cursor = "grabbing"

      const startX = e.clientX
      const startY = e.clientY
      const startL = parseInt(modal.style.left, 10) || 0
      const startT = parseInt(modal.style.top, 10) || 0

      const onMove = (moveEvent) => {
        modal.style.left = Math.max(0, Math.min(window.innerWidth - 120, startL + moveEvent.clientX - startX)) + "px"
        modal.style.top = Math.max(0, Math.min(window.innerHeight - 60, startT + moveEvent.clientY - startY)) + "px"
      }

      const onUp = () => {
        handle.style.cursor = "grab"
        document.removeEventListener("mousemove", onMove)
        document.removeEventListener("mouseup", onUp)
      }

      document.addEventListener("mousemove", onMove)
      document.addEventListener("mouseup", onUp)
    })
  }

  async selectFile(event) {
    const button = event.currentTarget
    const path = button.dataset.path
    if (!path) return
    if (this.dirty && !window.confirm("Tenés cambios sin guardar. ¿Cambiar de archivo igual?")) return

    this.clearError()

    try {
      const response = await fetch(`${this.baseUrl}/read?path=${encodeURIComponent(path)}`, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin"
      })
      const data = await response.json()
      if (!response.ok || !data.success) throw new Error(data.error || "No se pudo abrir el archivo")

      this.currentPath = data.path
      this.dirty = false
      this.filenameTarget.textContent = data.path.split("/").pop()

      if (data.editable) {
        this.contentTarget.innerHTML = `<textarea data-role="editor" class="w-full h-full min-h-[56vh] font-mono text-xs bg-transparent text-content border-none outline-none resize-none leading-relaxed"></textarea>`
        this.contentTarget.querySelector("textarea").value = data.content || ""
        this.contentTarget.querySelector("textarea").addEventListener("input", () => this.markDirty())
        this.saveButtonTarget.classList.remove("hidden")
      } else {
        this.contentTarget.innerHTML = `<pre class="text-xs font-mono text-content leading-relaxed whitespace-pre-wrap break-words"></pre>`
        this.contentTarget.querySelector("pre").textContent = data.content || ""
        this.saveButtonTarget.classList.add("hidden")
      }

      this.highlightSelection(path)
    } catch (error) {
      this.showError(error.message)
    }
  }

  async save(event) {
    if (event) event.preventDefault()
    const editor = this.contentTarget.querySelector("textarea[data-role='editor']")
    if (!editor || !this.currentPath) return

    this.clearError()

    try {
      const response = await fetch(`${this.baseUrl}/save`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        credentials: "same-origin",
        body: JSON.stringify({ file_path: this.currentPath, content: editor.value })
      })

      const data = await response.json()
      if (!response.ok || !data.success) throw new Error(data.error || "No se pudo guardar")

      this.dirty = false
      this.saveButtonTarget.textContent = "✅ Guardado"
      setTimeout(() => {
        if (this.hasSaveButtonTarget) this.saveButtonTarget.textContent = "💾 Guardar"
      }, 1400)
    } catch (error) {
      this.showError(error.message)
    }
  }

  markDirty() {
    this.dirty = true
    if (this.hasSaveButtonTarget) this.saveButtonTarget.textContent = "💾 Guardar *"
  }

  highlightSelection(path) {
    this.fileButtonTargets.forEach((button) => {
      button.classList.remove("bg-accent/20", "text-content")
      if (button.dataset.path === path) {
        button.classList.add("bg-accent/20", "text-content")
      }
    })
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
