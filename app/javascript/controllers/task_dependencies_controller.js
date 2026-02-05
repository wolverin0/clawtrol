import { Controller } from "@hotwired/stimulus"

// Manages task dependencies in the task panel
export default class extends Controller {
  static targets = ["searchInput", "suggestions", "dependenciesList", "blockingList"]
  static values = { taskId: Number, boardId: Number }

  connect() {
    this.searchTimeout = null
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  async search(event) {
    const query = event.target.value.trim()
    
    // Clear previous timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    // Handle #ID format for quick add
    const idMatch = query.match(/^#?(\d+)$/)
    if (idMatch) {
      this.searchTimeout = setTimeout(() => this.searchById(idMatch[1]), 200)
      return
    }

    // Handle text search with debounce
    if (query.length < 2) {
      this.hideSuggestions()
      return
    }

    this.searchTimeout = setTimeout(() => this.searchByText(query), 300)
  }

  async searchById(id) {
    try {
      const response = await fetch(`/api/v1/tasks/${id}`, {
        headers: this.headers()
      })
      
      if (response.ok) {
        const task = await response.json()
        if (task.id !== this.taskIdValue) {
          this.showSuggestion(task)
        }
      } else {
        this.showNoResults()
      }
    } catch (error) {
      console.error("Error searching task by ID:", error)
    }
  }

  async searchByText(query) {
    try {
      const response = await fetch(`/api/v1/tasks?board_id=${this.boardIdValue}`, {
        headers: this.headers()
      })
      
      if (response.ok) {
        const tasks = await response.json()
        const filtered = tasks.filter(t => 
          t.id !== this.taskIdValue && 
          t.name.toLowerCase().includes(query.toLowerCase())
        ).slice(0, 8)
        
        if (filtered.length > 0) {
          this.showSuggestions(filtered)
        } else {
          this.showNoResults()
        }
      }
    } catch (error) {
      console.error("Error searching tasks:", error)
    }
  }

  showSuggestion(task) {
    this.showSuggestions([task])
  }

  showSuggestions(tasks) {
    if (!this.hasSuggestionsTarget) return

    const html = tasks.map(task => `
      <button type="button"
              class="w-full flex items-center gap-2 px-3 py-2 text-sm text-left hover:bg-bg-elevated cursor-pointer transition-colors"
              data-action="click->task-dependencies#addDependency"
              data-task-id="${task.id}"
              data-task-name="${this.escapeHtml(task.name)}">
        <span class="font-mono text-xs text-content-muted">#${task.id}</span>
        <span class="truncate flex-1 ${task.status === 'done' || task.status === 'archived' ? 'line-through text-content-muted' : 'text-content'}">${this.escapeHtml(task.name.substring(0, 40))}</span>
        <span class="text-[10px] px-1.5 py-0.5 rounded bg-bg-elevated text-content-muted">${task.status}</span>
      </button>
    `).join("")

    this.suggestionsTarget.innerHTML = html
    this.suggestionsTarget.classList.remove("hidden")
  }

  showNoResults() {
    if (!this.hasSuggestionsTarget) return
    
    this.suggestionsTarget.innerHTML = `
      <div class="px-3 py-2 text-sm text-content-muted">No tasks found</div>
    `
    this.suggestionsTarget.classList.remove("hidden")
  }

  hideSuggestions() {
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.add("hidden")
    }
  }

  showSuggestions() {
    // Show suggestions on focus if there's a query
    const query = this.searchInputTarget.value.trim()
    if (query.length >= 2) {
      this.search({ target: this.searchInputTarget })
    }
  }

  async addDependency(event) {
    const taskId = event.currentTarget.dataset.taskId
    const taskName = event.currentTarget.dataset.taskName
    
    try {
      const response = await fetch(`/api/v1/tasks/${this.taskIdValue}/add_dependency`, {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({ depends_on_id: taskId })
      })

      if (response.ok) {
        const data = await response.json()
        this.addDependencyToList(data.dependency.depends_on)
        this.searchInputTarget.value = ""
        this.hideSuggestions()
        this.showToast(`Added dependency on #${taskId}`, "success")
        
        // Reload the page to update blocked badge
        if (data.blocked) {
          window.location.reload()
        }
      } else {
        const error = await response.json()
        this.showToast(error.error || "Failed to add dependency", "error")
      }
    } catch (error) {
      console.error("Error adding dependency:", error)
      this.showToast("Failed to add dependency", "error")
    }
  }

  addDependencyToList(dep) {
    if (!this.hasDependenciesListTarget) return
    
    // Remove "no dependencies" message if present
    const noDepMsg = this.dependenciesListTarget.querySelector("p.italic")
    if (noDepMsg) noDepMsg.remove()

    const statusClass = dep.done ? "line-through text-content-muted" : "text-content"
    const checkMark = dep.done ? '<span class="text-green-400 text-xs">✅</span>' : ""
    
    const html = `
      <div class="flex items-center gap-2 text-sm py-1 group" data-dependency-id="${dep.id}">
        <span class="text-content-muted font-mono text-xs">#${dep.id}</span>
        <span class="${statusClass} flex-1 truncate">${this.escapeHtml(dep.name.substring(0, 35))}</span>
        ${checkMark}
        <button type="button"
                data-action="click->task-dependencies#remove"
                data-dep-id="${dep.id}"
                class="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-300 text-xs p-1 cursor-pointer transition-opacity"
                title="Remove dependency">
          ✕
        </button>
      </div>
    `
    this.dependenciesListTarget.insertAdjacentHTML("beforeend", html)
  }

  async remove(event) {
    const depId = event.currentTarget.dataset.depId
    
    try {
      const response = await fetch(`/api/v1/tasks/${this.taskIdValue}/remove_dependency?depends_on_id=${depId}`, {
        method: "DELETE",
        headers: this.headers()
      })

      if (response.ok) {
        // Remove from list
        const item = this.dependenciesListTarget.querySelector(`[data-dependency-id="${depId}"]`)
        if (item) item.remove()
        
        // Also remove from blocking list if present
        if (this.hasBlockingListTarget) {
          const blockingItem = this.blockingListTarget.querySelector(`[data-dependency-id="${depId}"]`)
          if (blockingItem) blockingItem.remove()
        }
        
        this.showToast(`Removed dependency on #${depId}`, "success")
        
        // Reload to update blocked status
        const data = await response.json()
        if (!data.blocked) {
          window.location.reload()
        }
      } else {
        const error = await response.json()
        this.showToast(error.error || "Failed to remove dependency", "error")
      }
    } catch (error) {
      console.error("Error removing dependency:", error)
      this.showToast("Failed to remove dependency", "error")
    }
  }

  headers() {
    const token = document.querySelector('meta[name="api-token"]')?.content
    return {
      "Content-Type": "application/json",
      "Authorization": token ? `Bearer ${token}` : "",
      "Accept": "application/json"
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  showToast(message, type = "info") {
    // Use existing toast system if available, otherwise console log
    if (window.showToast) {
      window.showToast(message, type)
    } else {
      console.log(`[${type}] ${message}`)
    }
  }
}
