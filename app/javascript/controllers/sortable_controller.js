import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="sortable"
// Used for kanban board column drag-and-drop
export default class extends Controller {
  static values = {
    group: String,
    status: String,
    url: String
  }

  connect() {
    const options = {
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      delay: 150,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      emptyInsertThreshold: 50,
      swapThreshold: 0.65,
      invertSwap: true,
      filter: '[style*="display: none"]',
      onMove: this.move.bind(this),
      onUpdate: this.handleUpdate.bind(this)
    }

    // Board mode: enable cross-column dragging
    if (this.hasGroupValue) {
      options.group = this.groupValue
      options.onAdd = this.handleAdd.bind(this)
    }

    this.sortable = Sortable.create(this.element, options)
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  move(event) {
    // Don't allow moving hidden (filtered) items
    if (event.related?.style?.display === 'none') {
      return false
    }
    return true
  }

  // Handle reordering within the same column
  async handleUpdate(event) {
    if (!this.hasUrlValue) return

    // Get all task IDs in their new order
    const taskIds = Array.from(this.element.querySelectorAll("[data-task-id]"))
      .map(el => el.dataset.taskId)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ task_ids: taskIds, status: this.statusValue })
      })

      if (!response.ok) {
        console.error("Failed to update task positions")
      }
    } catch (error) {
      console.error("Error updating task positions:", error)
    }
  }

  // Handle task added from another column (board mode)
  async handleAdd(event) {
    if (!this.hasUrlValue || !this.hasStatusValue) return

    const taskId = event.item.dataset.taskId
    const newStatus = this.statusValue
    const oldStatus = event.from.id.replace("column-", "")

    // Get all task IDs in their new order (including the newly added one)
    const taskIds = Array.from(this.element.querySelectorAll("[data-task-id]"))
      .map(el => el.dataset.taskId)

    // Update the task's data attributes
    event.item.dataset.taskStatus = newStatus

    // Update column counters
    this.updateColumnCount(oldStatus, -1)
    this.updateColumnCount(newStatus, 1)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ id: taskId, status: newStatus, task_ids: taskIds })
      })

      if (!response.ok) {
        console.error("Failed to update task status")
      }
    } catch (error) {
      console.error("Error updating task status:", error)
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  updateColumnCount(status, delta) {
    // Update column header count
    const countEl = document.getElementById(`column-${status}-count`)
    if (countEl) {
      const currentCount = parseInt(countEl.textContent, 10) || 0
      countEl.textContent = currentCount + delta
    }
    // Update header stats count
    const headerCountEl = document.getElementById(`header-${status}-count`)
    if (headerCountEl) {
      const currentCount = parseInt(headerCountEl.textContent, 10) || 0
      headerCountEl.textContent = currentCount + delta
    }
  }
}
