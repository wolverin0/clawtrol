import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="completed-tasks"
export default class extends Controller {
  static targets = ["content", "wrapper", "count"]
  static values = {
    listId: String
  }

  connect() {
    // Find the completed section div
    this.completedSection = this.element.querySelector(`#completed-section-${this.listIdValue}`)

    if (!this.hasContentTarget || !this.hasWrapperTarget) return

    // Disable transitions for initial state
    this.wrapperTarget.style.transition = 'none'

    // Load saved state from localStorage
    const savedState = localStorage.getItem(this.storageKey)
    const isVisible = savedState === 'true'

    // Set initial state without animation
    if (isVisible) {
      this.wrapperTarget.style.gridTemplateRows = '1fr'
    } else {
      this.wrapperTarget.style.gridTemplateRows = '0fr'
      this.contentTarget.style.visibility = 'hidden'
    }

    // Re-enable transitions after initial state is set
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.wrapperTarget.style.transition = ''
      })
    })

    // Listen for task events
    this.boundUpdateVisibility = this.updateVisibility.bind(this)
    window.addEventListener('task:toggled', this.boundUpdateVisibility)
    window.addEventListener('task:deleted', this.boundUpdateVisibility)
  }

  disconnect() {
    window.removeEventListener('task:toggled', this.boundUpdateVisibility)
    window.removeEventListener('task:deleted', this.boundUpdateVisibility)
  }

  updateVisibility() {
    if (!this.hasContentTarget) return

    const completedTasks = this.contentTarget.querySelectorAll('[data-task-id]')
    const count = completedTasks.length

    // Update count
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    // Hide section if no completed tasks
    if (count === 0 && this.completedSection) {
      this.completedSection.classList.add('hidden')
    } else if (this.completedSection) {
      this.completedSection.classList.remove('hidden')
    }
  }

  toggle() {
    if (!this.hasContentTarget || !this.hasWrapperTarget) return

    const isCurrentlyVisible = this.wrapperTarget.style.gridTemplateRows === '1fr'

    if (isCurrentlyVisible) {
      this.collapse()
      this.saveState(false)
    } else {
      this.expand()
      this.saveState(true)
    }
  }

  expand() {
    this.contentTarget.style.visibility = 'visible'
    this.wrapperTarget.style.gridTemplateRows = '1fr'
  }

  collapse() {
    this.wrapperTarget.style.gridTemplateRows = '0fr'
    // Hide content after animation completes
    setTimeout(() => {
      if (this.wrapperTarget.style.gridTemplateRows === '0fr') {
        this.contentTarget.style.visibility = 'hidden'
      }
    }, 300)
  }

  saveState(isVisible) {
    localStorage.setItem(this.storageKey, isVisible.toString())
  }

  get storageKey() {
    return `task_list_${this.listIdValue}_completed_visible`
  }
}
