import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="projects-sortable"
export default class extends Controller {
  static values = { url: String, sync: String }

  connect() {
    // Determine if this is sidebar (links) or index (li elements)
    const isSidebar = this.element.id === "sidebar-projects"

    this.sortable = Sortable.create(this.element, {
      animation: 150,
      easing: "cubic-bezier(1, 0, 0, 1)",
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      chosenClass: "sortable-chosen",
      handle: isSidebar ? ".sidebar-project" : ".project-card",
      filter: "[data-sortable-exclude]",
      forceFallback: false,
      onStart: this.onStart.bind(this),
      onEnd: this.onEnd.bind(this),
      onMove: this.onMove.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
      this.sortable = null
    }
  }

  onStart(event) {
    this.element.classList.add("sorting-active")
  }

  onMove(event, originalEvent) {
    return true
  }

  onEnd(event) {
    this.element.classList.remove("sorting-active")

    if (event.oldIndex !== event.newIndex) {
      const projectIds = Array.from(this.element.querySelectorAll("[data-project-id]"))
        .map(element => {
          const id = element.dataset.projectId
          return id ? parseInt(id, 10) : null
        })
        .filter(id => id !== null)

      this.updatePositions(projectIds)
      this.syncOtherList(projectIds)
    }
  }

  syncOtherList(projectIds) {
    if (!this.hasSyncValue) return

    const otherList = document.getElementById(this.syncValue)
    if (!otherList) return

    // Find the first non-project element (like the + button) to insert before
    const nonProjectElement = otherList.querySelector(":scope > :not([data-project-id])")

    // Reorder the other list to match
    projectIds.forEach(id => {
      const element = otherList.querySelector(`[data-project-id="${id}"]`)
      if (element) {
        if (nonProjectElement) {
          otherList.insertBefore(element, nonProjectElement)
        } else {
          otherList.appendChild(element)
        }
      }
    })
  }

  async updatePositions(projectIds) {
    this.dispatchTurboEvent("turbo:submit-start")

    try {
      const url = this.hasUrlValue ? this.urlValue : "/projects/reorder"
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ project_ids: projectIds })
      })

      if (!response.ok) {
        const errorText = await response.text().catch(() => "Unknown error")
        throw new Error(`Failed to update project positions: ${response.status} ${errorText}`)
      }

      this.dispatch("success", { detail: { projectIds } })
    } catch (error) {
      console.error("Error updating project positions:", error)
      this.dispatch("error", { detail: { error: error.message } })
    } finally {
      this.dispatchTurboEvent("turbo:submit-end")
    }
  }

  dispatchTurboEvent(name) {
    const event = new CustomEvent(name, {
      bubbles: true,
      cancelable: true
    })
    document.dispatchEvent(event)
  }

  get csrfToken() {
    const metaTag = document.querySelector("meta[name='csrf-token']")
    if (!metaTag) {
      console.warn("CSRF token not found")
      return ""
    }
    return metaTag.content
  }
}

