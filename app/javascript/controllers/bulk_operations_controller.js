import { Controller } from "@hotwired/stimulus"

// Handles multi-select and bulk actions on task cards
export default class extends Controller {
  static targets = ["toggleButton", "counter", "actionBar", "checkbox"]
  static values = {
    url: String,
    active: { type: Boolean, default: false }
  }

  connect() {
    this.selectedIds = new Set()
    this.lastSelectedIndex = null
    this.allCards = []
    this.updateUI()
  }

  // Toggle selection mode on/off
  toggle() {
    this.activeValue = !this.activeValue
    this.selectedIds.clear()
    this.lastSelectedIndex = null
    this.updateUI()
  }

  // Exit selection mode
  exit() {
    this.activeValue = false
    this.selectedIds.clear()
    this.lastSelectedIndex = null
    this.updateUI()
  }

  // Select all visible tasks
  selectAll() {
    this.getAllCards().forEach(card => {
      const id = card.dataset.taskId
      if (id) this.selectedIds.add(id)
    })
    this.updateUI()
  }

  // Deselect all
  deselectAll() {
    this.selectedIds.clear()
    this.lastSelectedIndex = null
    this.updateUI()
  }

  // Handle card click for selection
  selectCard(event) {
    if (!this.activeValue) return

    const card = event.currentTarget.closest("[data-task-id]")
    if (!card) return

    const taskId = card.dataset.taskId
    const cards = this.getAllCards()
    const currentIndex = cards.findIndex(c => c.dataset.taskId === taskId)

    // Shift+click for range select
    if (event.shiftKey && this.lastSelectedIndex !== null) {
      const start = Math.min(this.lastSelectedIndex, currentIndex)
      const end = Math.max(this.lastSelectedIndex, currentIndex)
      
      for (let i = start; i <= end; i++) {
        const id = cards[i].dataset.taskId
        if (id) this.selectedIds.add(id)
      }
    } else {
      // Toggle single selection
      if (this.selectedIds.has(taskId)) {
        this.selectedIds.delete(taskId)
      } else {
        this.selectedIds.add(taskId)
      }
      this.lastSelectedIndex = currentIndex
    }

    this.updateUI()
  }

  // Checkbox change handler
  checkboxChanged(event) {
    const checkbox = event.currentTarget
    const card = checkbox.closest("[data-task-id]")
    if (!card) return

    const taskId = card.dataset.taskId
    
    if (checkbox.checked) {
      this.selectedIds.add(taskId)
    } else {
      this.selectedIds.delete(taskId)
    }

    const cards = this.getAllCards()
    this.lastSelectedIndex = cards.findIndex(c => c.dataset.taskId === taskId)
    
    this.updateUI()
  }

  // Get all task cards in DOM order
  getAllCards() {
    return Array.from(this.element.querySelectorAll("[data-task-id]"))
  }

  // Bulk action: Move to status
  async moveToStatus(event) {
    const status = event.currentTarget.dataset.status
    if (!status || this.selectedIds.size === 0) return

    await this.performBulkAction("move_status", status)
  }

  // Bulk action: Change model
  async changeModel(event) {
    const model = event.currentTarget.dataset.model
    if (!model || this.selectedIds.size === 0) return

    await this.performBulkAction("change_model", model)
  }

  // Bulk action: Archive
  async archive() {
    if (this.selectedIds.size === 0) return
    await this.performBulkAction("archive", null)
  }

  // Bulk action: Archive all done tasks
  async archiveAllDone() {
    const doneColumn = this.element.querySelector("#column-done")
    if (!doneColumn) return

    const doneCards = doneColumn.querySelectorAll("[data-task-id]")
    const ids = Array.from(doneCards).map(c => c.dataset.taskId).filter(Boolean)
    
    if (ids.length === 0) return

    await this.performBulkActionWithIds(ids, "archive", null)
  }

  // Bulk action: Delete (with confirmation)
  async deleteSelected() {
    if (this.selectedIds.size === 0) return

    const count = this.selectedIds.size
    const confirmed = confirm(`Are you sure you want to delete ${count} task${count > 1 ? 's' : ''}? This cannot be undone.`)
    
    if (!confirmed) return

    await this.performBulkAction("delete", null)
  }

  // Perform bulk action
  async performBulkAction(action, value) {
    const ids = Array.from(this.selectedIds)
    await this.performBulkActionWithIds(ids, action, value)
  }

  async performBulkActionWithIds(ids, action, value) {
    if (ids.length === 0) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        },
        body: JSON.stringify({
          task_ids: ids,
          action: action,
          value: value
        })
      })

      if (response.ok) {
        // Clear selection after successful action
        this.selectedIds.clear()
        this.lastSelectedIndex = null

        // Process turbo stream response
        const contentType = response.headers.get("Content-Type")
        if (contentType && contentType.includes("turbo-stream")) {
          const html = await response.text()
          Turbo.renderStreamMessage(html)
        } else {
          // Fallback: reload page
          window.location.reload()
        }

        this.updateUI()
      } else {
        const error = await response.text()
        console.error("Bulk action failed:", error)
        alert("Failed to perform bulk action. Please try again.")
      }
    } catch (error) {
      console.error("Bulk action error:", error)
      alert("Failed to perform bulk action. Please try again.")
    }
  }

  // Update all UI elements based on current state
  updateUI() {
    const active = this.activeValue
    const count = this.selectedIds.size

    // Update toggle button appearance
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.classList.toggle("bg-accent", active)
      this.toggleButtonTarget.classList.toggle("text-white", active)
      this.toggleButtonTarget.classList.toggle("bg-bg-elevated", !active)
      this.toggleButtonTarget.classList.toggle("text-content-secondary", !active)
    }

    // Update counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${count} selected`
      this.counterTarget.classList.toggle("hidden", !active || count === 0)
    }

    // Show/hide action bar
    if (this.hasActionBarTarget) {
      this.actionBarTarget.classList.toggle("hidden", !active || count === 0)
      this.actionBarTarget.classList.toggle("translate-y-0", active && count > 0)
      this.actionBarTarget.classList.toggle("translate-y-full", !active || count === 0)
    }

    // Update checkboxes on cards
    this.element.querySelectorAll("[data-bulk-checkbox]").forEach(wrapper => {
      wrapper.classList.toggle("hidden", !active)
    })

    // Update card selection state
    this.getAllCards().forEach(card => {
      const taskId = card.dataset.taskId
      const isSelected = this.selectedIds.has(taskId)
      
      card.classList.toggle("ring-2", isSelected)
      card.classList.toggle("ring-accent", isSelected)
      card.classList.toggle("bg-accent/10", isSelected)

      // Update checkbox
      const checkbox = card.querySelector("[data-bulk-operations-target='checkbox']")
      if (checkbox) {
        checkbox.checked = isSelected
      }
    })

    // Show/hide archive all done button
    const archiveDoneBtn = this.element.querySelector("[data-archive-done-btn]")
    if (archiveDoneBtn) {
      archiveDoneBtn.classList.toggle("hidden", !active)
    }
  }

  // Handle activeValue changes
  activeValueChanged() {
    this.updateUI()
  }
}
