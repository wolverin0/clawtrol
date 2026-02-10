import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="diff-viewer"
// Manages the visual diff viewer for task file changes
export default class extends Controller {
  static targets = [
    "container",
    "diffPanel",
    "diffContent",
    "fileName",
    "stats",
    "fullscreenModal",
    "fullscreenContent",
    "fullscreenFileName",
    "fullscreenStats",
    "collapsedSection"
  ]

  static values = {
    taskId: Number
  }

  connect() {
    this._handleEscape = this._handleEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleEscape)
  }

  async loadDiff(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const filePath = button.dataset.filePath
    const diffUrl = button.dataset.diffUrl
    
    if (!diffUrl) return

    // Show loading state
    if (this.hasDiffPanelTarget) {
      this.diffPanelTarget.classList.remove("hidden")
      this.diffContentTarget.innerHTML = this._loadingHtml()
    }

    try {
      const response = await fetch(diffUrl, {
        headers: { "Accept": "text/html" }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const html = await response.text()
      
      if (this.hasDiffContentTarget) {
        this.diffContentTarget.innerHTML = html
        this._attachCollapsedHandlers()
      }
      
      if (this.hasFileNameTarget) {
        this.fileNameTarget.textContent = filePath
      }
    } catch (error) {
      console.error("Diff viewer fetch error:", error)
      if (this.hasDiffContentTarget) {
        this.diffContentTarget.innerHTML = this._errorHtml(error.message)
      }
    }
  }

  close() {
    if (this.hasDiffPanelTarget) {
      this.diffPanelTarget.classList.add("hidden")
      this.diffContentTarget.innerHTML = ""
    }
  }

  expand() {
    const modal = this.fullscreenModalTarget
    if (!modal || !this.hasDiffContentTarget) return

    // Clone the content
    const contentClone = this.diffContentTarget.innerHTML
    const fileName = this.hasFileNameTarget ? this.fileNameTarget.textContent : "Diff"

    if (this.hasFullscreenFileNameTarget) {
      this.fullscreenFileNameTarget.textContent = fileName
    }

    if (this.hasFullscreenContentTarget) {
      this.fullscreenContentTarget.innerHTML = contentClone
      this._attachCollapsedHandlers(this.fullscreenContentTarget)
    }

    // Move to body to escape containing block
    document.body.appendChild(modal)
    document.body.style.overflow = "hidden"

    modal.classList.remove("hidden")
    modal.offsetHeight // force reflow
    modal.style.opacity = "0"
    requestAnimationFrame(() => {
      modal.style.transition = "opacity 150ms ease-out"
      modal.style.opacity = "1"
    })

    document.addEventListener("keydown", this._handleEscape)
  }

  collapse() {
    const modal = this.fullscreenModalTarget
    if (!modal) return

    document.body.style.overflow = ""

    modal.style.transition = "opacity 150ms ease-in"
    modal.style.opacity = "0"

    setTimeout(() => {
      modal.classList.add("hidden")
      modal.style.opacity = ""
      modal.style.transition = ""

      if (this.hasFullscreenContentTarget) {
        this.fullscreenContentTarget.innerHTML = ""
      }

      // Move back to original parent
      if (this._originalParent) {
        this._originalParent.appendChild(modal)
      }
    }, 150)

    document.removeEventListener("keydown", this._handleEscape)
  }

  toggleCollapsed(event) {
    const button = event.currentTarget
    const section = button.closest("[data-collapsed-section]")
    if (!section) return

    const content = section.querySelector("[data-collapsed-content]")
    const icon = button.querySelector("[data-collapse-icon]")
    
    if (content.classList.contains("hidden")) {
      content.classList.remove("hidden")
      icon.textContent = "▼"
      button.setAttribute("aria-expanded", "true")
    } else {
      content.classList.add("hidden")
      icon.textContent = "▶"
      button.setAttribute("aria-expanded", "false")
    }
  }

  _attachCollapsedHandlers(container = null) {
    const target = container || this.diffContentTarget
    const buttons = target.querySelectorAll("[data-action*='toggleCollapsed']")
    // Stimulus should auto-bind these, but ensure they work
  }

  _loadingHtml() {
    return `
      <div class="flex items-center justify-center py-12">
        <div class="flex items-center gap-2 text-content-muted">
          <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <span class="text-sm">Loading diff...</span>
        </div>
      </div>
    `
  }

  _errorHtml(message) {
    return `
      <div class="flex items-center justify-center py-12">
        <div class="text-center">
          <span class="text-3xl mb-3 block">⚠️</span>
          <p class="text-sm text-red-400">Failed to load diff: ${message}</p>
        </div>
      </div>
    `
  }

  _handleEscape(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.collapse()
    }
  }
}
