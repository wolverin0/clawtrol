import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
// Filter bar for board view - filters tasks by status, model, priority, agent assignment, nightly
export default class extends Controller {
  static targets = ["status", "model", "priority", "agent", "nightly", "chips", "tasksContainer"]
  static values = {
    boardId: Number
  }

  connect() {
    this.filters = {
      status: null,
      model: null,
      priority: null,
      hasAgent: null,
      nightly: null
    }
    this.loadFromUrl()
  }

  // Load filters from URL params on page load
  loadFromUrl() {
    const params = new URLSearchParams(window.location.search)
    
    if (params.get("filter_status")) {
      this.filters.status = params.get("filter_status")
      if (this.hasStatusTarget) this.statusTarget.value = this.filters.status
    }
    if (params.get("filter_model")) {
      this.filters.model = params.get("filter_model")
      if (this.hasModelTarget) this.modelTarget.value = this.filters.model
    }
    if (params.get("filter_priority")) {
      this.filters.priority = params.get("filter_priority")
      if (this.hasPriorityTarget) this.priorityTarget.value = this.filters.priority
    }
    if (params.get("filter_agent")) {
      this.filters.hasAgent = params.get("filter_agent")
      if (this.hasAgentTarget) this.agentTarget.value = this.filters.hasAgent
    }
    if (params.get("filter_nightly")) {
      this.filters.nightly = params.get("filter_nightly")
      this.updateNightlyButton()
    }

    this.updateChips()
    this.applyFilters()
  }

  // Toggle nightly filter
  toggleNightly() {
    if (this.filters.nightly === "true") {
      this.filters.nightly = null
    } else {
      this.filters.nightly = "true"
    }
    this.updateNightlyButton()
    this.onFilterChange()
  }

  // Update nightly button appearance
  updateNightlyButton() {
    if (!this.hasNightlyTarget) return
    
    if (this.filters.nightly === "true") {
      this.nightlyTarget.classList.add("nightly-filter-active")
      this.nightlyTarget.classList.remove("text-content-secondary")
    } else {
      this.nightlyTarget.classList.remove("nightly-filter-active")
      this.nightlyTarget.classList.add("text-content-secondary")
    }
  }

  // Handle filter change from dropdowns
  filterByStatus(event) {
    this.filters.status = event.target.value || null
    this.onFilterChange()
  }

  filterByModel(event) {
    this.filters.model = event.target.value || null
    this.onFilterChange()
  }

  filterByPriority(event) {
    this.filters.priority = event.target.value || null
    this.onFilterChange()
  }

  filterByAgent(event) {
    this.filters.hasAgent = event.target.value || null
    this.onFilterChange()
  }

  onFilterChange() {
    this.updateUrl()
    this.updateChips()
    this.applyFilters()
  }

  // Update URL with filter params (for bookmarking/sharing)
  updateUrl() {
    const url = new URL(window.location)
    
    if (this.filters.status) {
      url.searchParams.set("filter_status", this.filters.status)
    } else {
      url.searchParams.delete("filter_status")
    }
    
    if (this.filters.model) {
      url.searchParams.set("filter_model", this.filters.model)
    } else {
      url.searchParams.delete("filter_model")
    }
    
    if (this.filters.priority) {
      url.searchParams.set("filter_priority", this.filters.priority)
    } else {
      url.searchParams.delete("filter_priority")
    }
    
    if (this.filters.hasAgent) {
      url.searchParams.set("filter_agent", this.filters.hasAgent)
    } else {
      url.searchParams.delete("filter_agent")
    }
    
    if (this.filters.nightly) {
      url.searchParams.set("filter_nightly", this.filters.nightly)
    } else {
      url.searchParams.delete("filter_nightly")
    }

    window.history.replaceState({}, "", url)
  }

  // Update the chips display
  updateChips() {
    if (!this.hasChipsTarget) return

    const chips = []
    
    if (this.filters.status) {
      chips.push(this.createChip("Status", this.filters.status.replace("_", " "), "status"))
    }
    if (this.filters.model) {
      chips.push(this.createChip("Model", this.filters.model, "model"))
    }
    if (this.filters.priority) {
      chips.push(this.createChip("Priority", this.filters.priority, "priority"))
    }
    if (this.filters.hasAgent) {
      const label = this.filters.hasAgent === "true" ? "Has agent" : "No agent"
      chips.push(this.createChip("Agent", label, "hasAgent"))
    }
    if (this.filters.nightly) {
      chips.push(this.createChip("🌙", "Nightbeat", "nightly"))
    }

    this.chipsTarget.innerHTML = chips.join("")
  }

  createChip(label, value, filterKey) {
    return `
      <span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-accent/20 text-accent">
        <span class="text-content-muted">${label}:</span>
        <span>${value}</span>
        <button type="button" 
                data-action="click->filter#removeFilter"
                data-filter-key="${filterKey}"
                class="ml-0.5 hover:text-accent-hover cursor-pointer">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-3 h-3">
            <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
          </svg>
        </button>
      </span>
    `
  }

  removeFilter(event) {
    const filterKey = event.currentTarget.dataset.filterKey
    this.filters[filterKey] = null

    // Reset the corresponding dropdown
    switch (filterKey) {
      case "status":
        if (this.hasStatusTarget) this.statusTarget.value = ""
        break
      case "model":
        if (this.hasModelTarget) this.modelTarget.value = ""
        break
      case "priority":
        if (this.hasPriorityTarget) this.priorityTarget.value = ""
        break
      case "hasAgent":
        if (this.hasAgentTarget) this.agentTarget.value = ""
        break
      case "nightly":
        this.updateNightlyButton()
        break
    }

    this.onFilterChange()
  }

  clearAll() {
    this.filters = {
      status: null,
      model: null,
      priority: null,
      hasAgent: null,
      nightly: null
    }

    // Reset all dropdowns
    if (this.hasStatusTarget) this.statusTarget.value = ""
    if (this.hasModelTarget) this.modelTarget.value = ""
    if (this.hasPriorityTarget) this.priorityTarget.value = ""
    if (this.hasAgentTarget) this.agentTarget.value = ""
    this.updateNightlyButton()

    this.onFilterChange()
  }

  // Apply filters to task cards (client-side filtering)
  applyFilters() {
    const taskCards = document.querySelectorAll("[data-task-card]")
    let visibleCount = 0
    let hiddenCount = 0

    taskCards.forEach(card => {
      const matchesAll = this.taskMatchesFilters(card)
      
      if (matchesAll) {
        card.classList.remove("hidden", "filter-hidden")
        visibleCount++
      } else {
        card.classList.add("filter-hidden")
        hiddenCount++
      }
    })

    // Update column counts if needed
    this.updateColumnVisibility()
  }

  taskMatchesFilters(card) {
    // Status filter
    if (this.filters.status) {
      const taskStatus = card.dataset.taskStatus
      if (taskStatus !== this.filters.status) return false
    }

    // Model filter
    if (this.filters.model) {
      const taskModel = card.dataset.taskModel || ""
      if (taskModel !== this.filters.model) return false
    }

    // Priority filter
    if (this.filters.priority) {
      const taskPriority = card.dataset.taskPriority || "none"
      if (taskPriority !== this.filters.priority) return false
    }

    // Agent filter
    if (this.filters.hasAgent) {
      const hasAgent = card.dataset.taskHasAgent === "true"
      const wantsAgent = this.filters.hasAgent === "true"
      if (hasAgent !== wantsAgent) return false
    }

    // Nightly filter
    if (this.filters.nightly === "true") {
      const isNightly = card.dataset.taskNightly === "true"
      if (!isNightly) return false
    }

    return true
  }

  updateColumnVisibility() {
    const columns = document.querySelectorAll("[data-column-status]")
    
    columns.forEach(column => {
      const visibleTasks = column.querySelectorAll("[data-task-card]:not(.filter-hidden)")
      const countBadge = column.querySelector("[data-filter-count]")
      
      if (countBadge) {
        const totalTasks = column.querySelectorAll("[data-task-card]").length
        if (this.hasActiveFilters()) {
          countBadge.textContent = `${visibleTasks.length}/${totalTasks}`
        } else {
          countBadge.textContent = totalTasks.toString()
        }
      }
    })
  }

  hasActiveFilters() {
    return !!(this.filters.status || this.filters.model || this.filters.priority || this.filters.hasAgent || this.filters.nightly)
  }
}
