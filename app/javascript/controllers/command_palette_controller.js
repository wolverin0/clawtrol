import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "input", "results"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault()
      this.toggle()
    }
    if (e.key === "Escape" && this.isOpen()) {
      this.close()
    }
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (this.hasDialogTarget) {
      this.dialogTarget.classList.remove("hidden")
      this.inputTarget?.focus()
    }
  }

  close() {
    if (this.hasDialogTarget) {
      this.dialogTarget.classList.add("hidden")
      this.inputTarget.value = ""
      if (this.hasResultsTarget) this.resultsTarget.innerHTML = ""
    }
  }

  isOpen() {
    return this.hasDialogTarget && !this.dialogTarget.classList.contains("hidden")
  }

  async search() {
    const query = this.inputTarget?.value?.trim()
    if (!query || query.length < 2) {
      if (this.hasResultsTarget) this.resultsTarget.innerHTML = ""
      return
    }

    try {
      const response = await fetch(`/search?q=${encodeURIComponent(query)}&format=json`, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const data = await response.json()
      this.renderResults(data)
    } catch (e) {
      // silently fail
    }
  }

  renderResults(data) {
    if (!this.hasResultsTarget) return
    const tasks = data.tasks || data
    if (!Array.isArray(tasks) || tasks.length === 0) {
      this.resultsTarget.innerHTML = '<div class="p-4 text-sm text-content-muted text-center">No results found</div>'
      return
    }

    this.resultsTarget.innerHTML = tasks.slice(0, 10).map(task => `
      <a href="/boards/${task.board_id}/tasks/${task.id}" class="block px-4 py-2 hover:bg-bg-elevated text-sm transition-colors">
        <div class="font-medium text-content">${this.escapeHtml(task.name || task.title || 'Untitled')}</div>
        <div class="text-xs text-content-muted">${this.escapeHtml(task.status || '')} · ${this.escapeHtml(task.board_name || '')}</div>
      </a>
    `).join('')
  }

  escapeHtml(str) {
    const div = document.createElement('div')
    div.textContent = str
    return div.innerHTML
  }
}
