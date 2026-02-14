import { Controller } from "@hotwired/stimulus"

// Enhanced command palette with quick actions + task search
// Ctrl+K / Cmd+K to open, arrow keys to navigate, Enter to select
export default class extends Controller {
  static targets = ["dialog", "input", "results"]

  static QUICK_ACTIONS = [
    { key: "board",      icon: "📋", label: "Go to Board…",           type: "nav",     url: null },
    { key: "dashboard",  icon: "📊", label: "Dashboard",              type: "nav",     url: "/dashboard" },
    { key: "analytics",  icon: "💰", label: "Cost Analytics",         type: "nav",     url: "/analytics" },
    { key: "nightshift", icon: "🌙", label: "Nightshift",             type: "nav",     url: "/nightshift" },
    { key: "factory",    icon: "🏭", label: "Factory Cycles",         type: "nav",     url: "/factory/cycles" },
    { key: "notifs",     icon: "🔔", label: "Notifications",          type: "nav",     url: "/notifications" },
    { key: "files",      icon: "📂", label: "File Browser",           type: "nav",     url: "/files" },
    { key: "saved",      icon: "🔗", label: "Saved Links",            type: "nav",     url: "/saved_links" },
    { key: "theme",      icon: "🎨", label: "Toggle Theme",           type: "action",  action: "toggleTheme" },
    { key: "scanlines", icon: "📺", label: "Toggle CRT Scanlines",   type: "action",  action: "toggleScanlines" },
    { key: "flicker",   icon: "⚡", label: "Toggle CRT Flicker",     type: "action",  action: "toggleFlicker" },
  ]

  connect() {
    this.handleKeydown = this._handleKeydown.bind(this)
    this.selectedIndex = -1
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  _handleKeydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault()
      this.toggle()
      return
    }

    if (!this.isOpen()) return

    if (e.key === "Escape") {
      e.preventDefault()
      this.close()
      return
    }

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this._moveSelection(1)
      return
    }

    if (e.key === "ArrowUp") {
      e.preventDefault()
      this._moveSelection(-1)
      return
    }

    if (e.key === "Enter") {
      e.preventDefault()
      this._executeSelected()
      return
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
      if (this.inputTarget) {
        this.inputTarget.setAttribute("aria-expanded", "true")
        this.inputTarget.focus()
      }
      this.selectedIndex = -1
      this._showQuickActions()
    }
  }

  close() {
    if (this.hasDialogTarget) {
      this.dialogTarget.classList.add("hidden")
      this.inputTarget.value = ""
      this.inputTarget.removeAttribute("aria-activedescendant")
      this.inputTarget.setAttribute("aria-expanded", "false")
      this.selectedIndex = -1
      if (this.hasResultsTarget) this.resultsTarget.innerHTML = ""
    }
  }

  isOpen() {
    return this.hasDialogTarget && !this.dialogTarget.classList.contains("hidden")
  }

  async search() {
    const query = this.inputTarget?.value?.trim()
    this.selectedIndex = -1

    if (!query || query.length < 1) {
      this._showQuickActions()
      return
    }

    // Filter quick actions by query first
    const matchingActions = this.constructor.QUICK_ACTIONS.filter(a =>
      a.label.toLowerCase().includes(query.toLowerCase()) ||
      a.key.toLowerCase().includes(query.toLowerCase())
    )

    // If query is short, show filtered quick actions
    if (query.length < 2) {
      this._renderFilteredActions(matchingActions)
      return
    }

    // Search tasks + show matching quick actions
    try {
      const response = await fetch(`/search?q=${encodeURIComponent(query)}&format=json`, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) {
        this._renderFilteredActions(matchingActions)
        return
      }
      const data = await response.json()
      this._renderCombinedResults(matchingActions, data)
    } catch {
      this._renderFilteredActions(matchingActions)
    }
  }

  // --- Rendering ---

  _showQuickActions() {
    if (!this.hasResultsTarget) return
    const actions = this.constructor.QUICK_ACTIONS
    this.resultsTarget.setAttribute("role", "listbox")
    this.resultsTarget.setAttribute("aria-label", "Command results")
    this.resultsTarget.innerHTML = `
      <div class="px-3 py-2 text-xs text-content-muted uppercase tracking-wide font-medium" role="presentation">Quick Actions</div>
      ${actions.map((a, i) => this._renderActionItem(a, i)).join("")}
    `
    this._allItems = actions.map(a => ({ type: a.type, url: a.url, action: a.action }))
  }

  _renderFilteredActions(actions) {
    if (!this.hasResultsTarget) return
    if (actions.length === 0) {
      this.resultsTarget.innerHTML = '<div class="p-4 text-sm text-content-muted text-center">No matches</div>'
      this._allItems = []
      return
    }
    this.resultsTarget.innerHTML = actions.map((a, i) => this._renderActionItem(a, i)).join("")
    this._allItems = actions.map(a => ({ type: a.type, url: a.url, action: a.action }))
  }

  _renderCombinedResults(actions, data) {
    if (!this.hasResultsTarget) return
    const tasks = data.tasks || data
    let html = ""
    let items = []

    // Quick actions section
    if (actions.length > 0) {
      html += `<div class="px-3 py-2 text-xs text-content-muted uppercase tracking-wide font-medium">Actions</div>`
      actions.forEach((a, i) => {
        html += this._renderActionItem(a, items.length)
        items.push({ type: a.type, url: a.url, action: a.action })
      })
    }

    // Task results section
    if (Array.isArray(tasks) && tasks.length > 0) {
      html += `<div class="px-3 py-2 text-xs text-content-muted uppercase tracking-wide font-medium border-t border-border">Tasks</div>`
      tasks.slice(0, 8).forEach(task => {
        const url = `/boards/${task.board_id}/tasks/${task.id}`
        html += `
          <a href="${url}" id="palette-option-${items.length}" data-palette-index="${items.length}"
             role="option" aria-selected="false"
             class="palette-item flex items-center gap-3 px-4 py-2 hover:bg-bg-hover text-sm transition-colors cursor-pointer">
            <span class="text-base flex-shrink-0">${this._statusIcon(task.status)}</span>
            <div class="min-w-0 flex-1">
              <div class="font-medium text-content truncate">#${task.id} ${this._escapeHtml(task.name || task.title || "Untitled")}</div>
              <div class="text-xs text-content-muted">${this._escapeHtml(task.status || "")} · ${this._escapeHtml(task.board_name || "")}</div>
            </div>
            ${task.model ? `<span class="text-xs px-1.5 py-0.5 rounded bg-bg-surface text-content-muted">${this._escapeHtml(task.model)}</span>` : ""}
          </a>`
        items.push({ type: "nav", url })
      })
    }

    if (items.length === 0) {
      html = '<div class="p-4 text-sm text-content-muted text-center">No results found</div>'
    }

    this.resultsTarget.innerHTML = html
    this._allItems = items
  }

  _renderActionItem(action, index) {
    return `
      <div id="palette-option-${index}" data-palette-index="${index}"
           role="option" aria-selected="false"
           class="palette-item flex items-center gap-3 px-4 py-2 hover:bg-bg-hover text-sm transition-colors cursor-pointer"
           data-action="click->command-palette#_onItemClick">
        <span class="text-base flex-shrink-0">${action.icon}</span>
        <span class="text-content">${action.label}</span>
        ${action.type === "action" ? '<span class="ml-auto text-xs text-content-muted">⚡</span>' : ""}
      </div>`
  }

  _statusIcon(status) {
    const icons = {
      inbox: "📥", up_next: "⏳", in_progress: "🔴",
      in_review: "👁️", done: "✅", archived: "📦"
    }
    return icons[status] || "📋"
  }

  // --- Keyboard navigation ---

  _moveSelection(delta) {
    if (!this._allItems || this._allItems.length === 0) return
    const items = this.resultsTarget.querySelectorAll(".palette-item")
    if (items.length === 0) return

    // Remove current highlight + aria-selected
    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
      items[this.selectedIndex].classList.remove("bg-bg-hover")
      items[this.selectedIndex].setAttribute("aria-selected", "false")
    }

    this.selectedIndex = Math.max(0, Math.min(items.length - 1, this.selectedIndex + delta))

    // Add new highlight + aria-selected + aria-activedescendant
    const selected = items[this.selectedIndex]
    selected.classList.add("bg-bg-hover")
    selected.setAttribute("aria-selected", "true")
    selected.scrollIntoView({ block: "nearest" })

    // Update aria-activedescendant on input to announce selection to screen readers
    if (this.inputTarget && selected.id) {
      this.inputTarget.setAttribute("aria-activedescendant", selected.id)
    }
  }

  _executeSelected() {
    if (!this._allItems || this.selectedIndex < 0 || this.selectedIndex >= this._allItems.length) {
      // If nothing selected, try to search
      this.search()
      return
    }

    const item = this._allItems[this.selectedIndex]

    if (item.type === "action") {
      this._runAction(item.action)
    } else if (item.type === "nav" && item.url) {
      window.Turbo?.visit(item.url) || (window.location.href = item.url)
      this.close()
    }
  }

  _onItemClick(event) {
    const el = event.currentTarget
    const index = parseInt(el.dataset.paletteIndex, 10)
    if (isNaN(index) || !this._allItems || index >= this._allItems.length) return

    const item = this._allItems[index]
    if (item.type === "action") {
      this._runAction(item.action)
    } else if (item.type === "nav" && item.url) {
      window.Turbo?.visit(item.url) || (window.location.href = item.url)
      this.close()
    }
  }

  _runAction(actionName) {
    if (actionName === "toggleTheme") {
      // Dispatch theme toggle event (works with existing theme controller)
      const btn = document.querySelector("[data-action*='theme#toggle']") ||
                  document.querySelector("[data-action*='theme#cycle']")
      if (btn) btn.click()
      this.close()
    } else if (actionName === "toggleScanlines") {
      const off = document.body.classList.toggle("no-scanlines")
      localStorage.setItem("clawtrol-no-scanlines", off.toString())
      this.close()
    } else if (actionName === "toggleFlicker") {
      const on = document.body.classList.toggle("crt-flicker")
      localStorage.setItem("clawtrol-crt-flicker", on.toString())
      this.close()
    }
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
