import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drag-assign"
// Handles dragging agent persona badges onto task cards to assign them
export default class extends Controller {
  static targets = ["sidebar", "toggle", "badge"]
  static values = {
    apiBase: { type: String, default: "/api/v1" },
    collapsed: { type: Boolean, default: true }
  }

  connect() {
    // Listen for custom events from task cards
    this.handleDragOver = this._handleDragOver.bind(this)
    this.handleDrop = this._handleDrop.bind(this)
    this.handleDragLeave = this._handleDragLeave.bind(this)
    
    // Attach drop listeners to all task cards
    this._attachDropListeners()
    
    // Observe DOM changes to attach listeners to new task cards (Turbo Stream)
    this.observer = new MutationObserver(() => this._attachDropListeners())
    const columnsContainer = document.querySelector('[data-mobile-columns-target="columnsContainer"]')
    if (columnsContainer) {
      this.observer.observe(columnsContainer, { childList: true, subtree: true })
    }

    // Restore collapsed state from localStorage
    const stored = localStorage.getItem("drag-assign-collapsed")
    if (stored !== null) {
      this.collapsedValue = stored === "true"
    }
    this._updateSidebarVisibility()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    this._detachDropListeners()
  }

  // Toggle sidebar visibility
  toggleSidebar() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem("drag-assign-collapsed", this.collapsedValue)
    this._updateSidebarVisibility()
  }

  _updateSidebarVisibility() {
    if (!this.hasSidebarTarget) return
    
    if (this.collapsedValue) {
      this.sidebarTarget.classList.add("hidden")
      if (this.hasToggleTarget) {
        this.toggleTarget.setAttribute("title", "Show Agent Personas")
        this.toggleTarget.querySelector("[data-chevron]")?.classList.remove("rotate-180")
      }
    } else {
      this.sidebarTarget.classList.remove("hidden")
      if (this.hasToggleTarget) {
        this.toggleTarget.setAttribute("title", "Hide Agent Personas")
        this.toggleTarget.querySelector("[data-chevron]")?.classList.add("rotate-180")
      }
    }
  }

  // === DRAG START (on persona badge) ===
  dragStart(event) {
    const personaId = event.currentTarget.dataset.personaId
    const personaName = event.currentTarget.dataset.personaName
    const personaEmoji = event.currentTarget.dataset.personaEmoji

    event.dataTransfer.setData("application/persona-id", personaId)
    event.dataTransfer.setData("text/plain", `${personaEmoji} ${personaName}`)
    event.dataTransfer.effectAllowed = "copy"

    // Visual feedback - add dragging class
    event.currentTarget.classList.add("opacity-50", "scale-95")

    // Highlight all task cards as potential drop targets
    document.querySelectorAll("[data-task-card]").forEach(card => {
      card.classList.add("ring-1", "ring-accent/30")
    })
  }

  // === DRAG END (on persona badge) ===
  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-50", "scale-95")

    // Remove drop target highlights
    document.querySelectorAll("[data-task-card]").forEach(card => {
      card.classList.remove("ring-1", "ring-accent/30", "ring-2", "ring-accent", "bg-accent/10")
    })
  }

  // === DROP HANDLERS (on task cards) ===
  _handleDragOver(event) {
    // Only accept persona drags
    if (!event.dataTransfer.types.includes("application/persona-id")) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"

    // Highlight the card
    const card = event.currentTarget.closest("[data-task-card]")
    if (card) {
      card.classList.add("ring-2", "ring-accent", "bg-accent/10")
      card.classList.remove("ring-1", "ring-accent/30")
    }
  }

  _handleDragLeave(event) {
    const card = event.currentTarget.closest("[data-task-card]")
    if (card && !card.contains(event.relatedTarget)) {
      card.classList.remove("ring-2", "ring-accent", "bg-accent/10")
      card.classList.add("ring-1", "ring-accent/30")
    }
  }

  async _handleDrop(event) {
    event.preventDefault()

    const personaId = event.dataTransfer.getData("application/persona-id")
    if (!personaId) return

    const card = event.currentTarget.closest("[data-task-card]")
    if (!card) return

    const taskId = card.dataset.taskId
    if (!taskId) return

    // Remove visual feedback
    card.classList.remove("ring-2", "ring-accent", "bg-accent/10", "ring-1", "ring-accent/30")

    // Make API call to assign persona
    await this._assignPersona(taskId, personaId, card)
  }

  // === UNASSIGN (click X button on persona badge in task card) ===
  async unassign(event) {
    event.preventDefault()
    event.stopPropagation()

    const taskId = event.currentTarget.dataset.taskId
    if (!taskId) return

    const card = document.getElementById(`task_${taskId}`)
    await this._assignPersona(taskId, null, card)
  }

  // === API CALL ===
  async _assignPersona(taskId, personaId, cardElement) {
    const csrfToken = document.querySelector("[name='csrf-token']")?.content

    try {
      const body = { task: { agent_persona_id: personaId } }
      
      const headers = {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      }

      // Add Bearer token if available (for API auth), otherwise session cookies are used
      const apiToken = this._getApiToken()
      if (apiToken) headers["Authorization"] = `Bearer ${apiToken}`

      const response = await fetch(`${this.apiBaseValue}/tasks/${taskId}`, {
        method: "PATCH",
        headers,
        body: JSON.stringify(body)
      })

      if (!response.ok) {
        console.error("Failed to assign persona:", response.statusText)
        return
      }

      const data = await response.json()
      
      // Update the card's persona badge
      this._updateCardBadge(cardElement, data.agent_persona)
      
      // Flash success
      if (cardElement) {
        cardElement.classList.add("ring-2", "ring-green-500/50")
        setTimeout(() => cardElement.classList.remove("ring-2", "ring-green-500/50"), 800)
      }
    } catch (error) {
      console.error("Error assigning persona:", error)
    }
  }

  _updateCardBadge(cardElement, persona) {
    if (!cardElement) return

    const badgeContainer = cardElement.querySelector("[data-persona-badge]")
    
    if (persona) {
      // Show/update badge
      if (badgeContainer) {
        badgeContainer.innerHTML = this._renderBadgeHTML(persona, cardElement.dataset.taskId)
        badgeContainer.classList.remove("hidden")
      }
    } else {
      // Hide badge
      if (badgeContainer) {
        badgeContainer.innerHTML = ""
        badgeContainer.classList.add("hidden")
      }
    }
  }

  _renderBadgeHTML(persona, taskId) {
    return `
      <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-accent/15 text-accent border border-accent/20">
        <span>${persona.emoji || '🤖'}</span>
        <span class="max-w-[60px] truncate">${persona.name}</span>
        <button type="button"
                data-action="click->drag-assign#unassign"
                data-task-id="${taskId}"
                class="ml-0.5 hover:text-red-400 transition-colors cursor-pointer"
                title="Unassign persona">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="w-3 h-3">
            <path d="M5.28 4.22a.75.75 0 0 0-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 1 0 1.06 1.06L8 9.06l2.72 2.72a.75.75 0 1 0 1.06-1.06L9.06 8l2.72-2.72a.75.75 0 0 0-1.06-1.06L8 6.94 5.28 4.22Z" />
          </svg>
        </button>
      </span>
    `
  }

  // === HELPERS ===
  _getApiToken() {
    // Try to get from meta tag or data attribute
    return document.querySelector("meta[name='api-token']")?.content || 
           document.querySelector("[data-api-token]")?.dataset.apiToken || ""
  }

  _attachDropListeners() {
    document.querySelectorAll("[data-task-card]").forEach(card => {
      if (card._dragAssignAttached) return
      card.addEventListener("dragover", this.handleDragOver)
      card.addEventListener("drop", this.handleDrop)
      card.addEventListener("dragleave", this.handleDragLeave)
      card._dragAssignAttached = true
    })
  }

  _detachDropListeners() {
    document.querySelectorAll("[data-task-card]").forEach(card => {
      card.removeEventListener("dragover", this.handleDragOver)
      card.removeEventListener("drop", this.handleDrop)
      card.removeEventListener("dragleave", this.handleDragLeave)
      card._dragAssignAttached = false
    })
  }
}
