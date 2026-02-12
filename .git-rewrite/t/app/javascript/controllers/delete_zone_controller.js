import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="delete-zone"
// A drop zone that appears during drag and deletes dropped tasks
export default class extends Controller {
  static targets = ["droparea"]
  static values = {
    url: String
  }

  connect() {
    // Store bound functions for proper cleanup
    this.boundShow = this.show.bind(this)
    this.boundHide = this.hide.bind(this)

    // Listen for drag events from sortable controllers
    document.addEventListener("sortable:dragstart", this.boundShow)
    document.addEventListener("sortable:dragend", this.boundHide)

    // Create sortable instance to accept drops
    this.sortable = Sortable.create(this.dropareaTarget, {
      group: "board",
      ghostClass: "hidden",
      onAdd: this.handleDrop.bind(this)
    })

    // Add hover effect when dragging over
    this.dropareaTarget.addEventListener("dragenter", this.highlightZone.bind(this))
    this.dropareaTarget.addEventListener("dragleave", this.unhighlightZone.bind(this))
  }

  disconnect() {
    document.removeEventListener("sortable:dragstart", this.boundShow)
    document.removeEventListener("sortable:dragend", this.boundHide)
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  show() {
    this.element.classList.remove("translate-y-full", "opacity-0")
    this.element.classList.add("translate-y-0", "opacity-100")
  }

  hide() {
    this.element.classList.remove("translate-y-0", "opacity-100")
    this.element.classList.add("translate-y-full", "opacity-0")
    this.unhighlightZone()
  }

  highlightZone() {
    this.dropareaTarget.classList.add("bg-red-500/40", "scale-[1.02]")
    this.dropareaTarget.classList.remove("bg-red-500/20")
  }

  unhighlightZone() {
    this.dropareaTarget.classList.remove("bg-red-500/40", "scale-[1.02]")
    this.dropareaTarget.classList.add("bg-red-500/20")
  }

  async handleDrop(event) {
    const item = event.item
    const taskId = item.dataset.taskId
    const oldStatus = item.dataset.taskStatus

    // Remove the item from DOM immediately
    item.remove()

    // Update the old column count
    this.updateColumnCount(oldStatus, -1)

    // Hide the zone
    this.hide()

    // Delete via API
    try {
      const response = await fetch(`${this.urlValue}/${taskId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (!response.ok) {
        console.error("Failed to delete task")
      }
    } catch (error) {
      console.error("Error deleting task:", error)
    }
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']").content
  }

  updateColumnCount(status, delta) {
    const countEl = document.getElementById(`column-${status}-count`)
    if (countEl) {
      const currentCount = parseInt(countEl.textContent, 10) || 0
      countEl.textContent = Math.max(0, currentCount + delta)
    }
    const headerCountEl = document.getElementById(`header-${status}-count`)
    if (headerCountEl) {
      const currentCount = parseInt(headerCountEl.textContent, 10) || 0
      headerCountEl.textContent = Math.max(0, currentCount + delta)
    }
  }
}
