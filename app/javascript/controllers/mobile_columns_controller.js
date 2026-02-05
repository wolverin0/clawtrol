import { Controller } from "@hotwired/stimulus"

/**
 * Mobile Columns Controller
 * 
 * Shows one kanban column at a time on mobile screens (<768px)
 * with a tab bar to switch between columns.
 * 
 * Features:
 * - Single column view on mobile
 * - Tab-based navigation
 * - Persists last active column in localStorage
 * - Optional swipe gesture support
 */
export default class extends Controller {
  static targets = ["tabs", "column", "tabButton", "columnsContainer"]
  static values = {
    activeColumn: { type: String, default: "inbox" }
  }

  connect() {
    // Restore last active column from localStorage
    const savedColumn = localStorage.getItem("mobileActiveColumn")
    if (savedColumn && this.validColumn(savedColumn)) {
      this.activeColumnValue = savedColumn
    }

    // Initial update
    this.updateView()

    // Handle window resize - re-check mobile state
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)

    // Setup swipe gestures
    this.setupSwipeGestures()
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
    this.teardownSwipeGestures()
  }

  handleResize() {
    this.updateView()
  }

  isMobile() {
    return window.innerWidth < 768
  }

  validColumn(column) {
    const columns = ["inbox", "up_next", "in_progress", "in_review", "done"]
    return columns.includes(column)
  }

  switch(event) {
    const column = event.currentTarget.dataset.column
    if (!this.validColumn(column)) return

    this.activeColumnValue = column
    localStorage.setItem("mobileActiveColumn", column)
    this.updateView()
  }

  updateView() {
    if (!this.isMobile()) {
      // On desktop, show all columns
      this.showAllColumns()
      return
    }

    // On mobile, show only the active column
    this.columnTargets.forEach(column => {
      const columnStatus = column.dataset.status
      if (columnStatus === this.activeColumnValue) {
        column.classList.remove("hidden")
        // Make column full width on mobile
        column.classList.add("mobile-active-column")
      } else {
        column.classList.add("hidden")
        column.classList.remove("mobile-active-column")
      }
    })

    // Update tab buttons
    this.tabButtonTargets.forEach(button => {
      const buttonColumn = button.dataset.column
      if (buttonColumn === this.activeColumnValue) {
        button.classList.add("mobile-tab-active")
        button.classList.remove("mobile-tab-inactive")
      } else {
        button.classList.remove("mobile-tab-active")
        button.classList.add("mobile-tab-inactive")
      }
    })
  }

  showAllColumns() {
    this.columnTargets.forEach(column => {
      column.classList.remove("hidden", "mobile-active-column")
    })
  }

  // Navigation helpers
  nextColumn() {
    const columns = ["inbox", "up_next", "in_progress", "in_review", "done"]
    const currentIndex = columns.indexOf(this.activeColumnValue)
    if (currentIndex < columns.length - 1) {
      this.activeColumnValue = columns[currentIndex + 1]
      localStorage.setItem("mobileActiveColumn", this.activeColumnValue)
      this.updateView()
    }
  }

  previousColumn() {
    const columns = ["inbox", "up_next", "in_progress", "in_review", "done"]
    const currentIndex = columns.indexOf(this.activeColumnValue)
    if (currentIndex > 0) {
      this.activeColumnValue = columns[currentIndex - 1]
      localStorage.setItem("mobileActiveColumn", this.activeColumnValue)
      this.updateView()
    }
  }

  // Swipe gesture support
  setupSwipeGestures() {
    if (!this.hasColumnsContainerTarget) return

    this.touchStartX = 0
    this.touchEndX = 0
    const minSwipeDistance = 50

    this.handleTouchStart = (e) => {
      this.touchStartX = e.changedTouches[0].screenX
    }

    this.handleTouchEnd = (e) => {
      if (!this.isMobile()) return
      
      this.touchEndX = e.changedTouches[0].screenX
      const swipeDistance = this.touchEndX - this.touchStartX

      if (Math.abs(swipeDistance) > minSwipeDistance) {
        if (swipeDistance > 0) {
          // Swiped right - go to previous column
          this.previousColumn()
        } else {
          // Swiped left - go to next column
          this.nextColumn()
        }
      }
    }

    this.columnsContainerTarget.addEventListener("touchstart", this.handleTouchStart, { passive: true })
    this.columnsContainerTarget.addEventListener("touchend", this.handleTouchEnd, { passive: true })
  }

  teardownSwipeGestures() {
    if (!this.hasColumnsContainerTarget) return
    
    this.columnsContainerTarget.removeEventListener("touchstart", this.handleTouchStart)
    this.columnsContainerTarget.removeEventListener("touchend", this.handleTouchEnd)
  }

  // Terminal toggle for bottom nav
  showTerminal() {
    // Dispatch event to toggle agent terminal
    const event = new CustomEvent("toggle-agent-terminal", { bubbles: true })
    this.element.dispatchEvent(event)
  }
}
