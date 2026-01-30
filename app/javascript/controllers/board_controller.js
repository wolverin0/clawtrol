import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="board"
export default class extends Controller {
  static targets = ["slidePanel", "slidePanelContent", "slideOverlay"]

  connect() {
    // Listen for turbo:frame-load to know when content is loaded in slide panel
    document.addEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  handleFrameLoad(event) {
    if (event.target.id === "task_detail_panel") {
      this.openSlidePanel()
    }
  }

  openSlidePanel(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.hasSlidePanelTarget) {
      this.slidePanelTarget.classList.remove("translate-x-full")
      this.slideOverlayTarget.classList.remove("opacity-0", "pointer-events-none")
      this.slideOverlayTarget.classList.add("opacity-100")
      document.body.classList.add("overflow-hidden")
    }
  }

  closeSlidePanel(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.hasSlidePanelTarget) {
      this.slidePanelTarget.classList.add("translate-x-full")
      this.slideOverlayTarget.classList.add("opacity-0", "pointer-events-none")
      this.slideOverlayTarget.classList.remove("opacity-100")
      document.body.classList.remove("overflow-hidden")
    }
  }

  openNewTaskModal(event) {
    event.preventDefault()
    // Use turbo to load the new task form
    Turbo.visit("/board/tasks/new", { frame: "new_task_modal" })
  }

  openTaskDetail(event) {
    event.preventDefault()
    event.stopPropagation()

    const taskUrl = event.currentTarget.dataset.taskUrl
    if (taskUrl) {
      // Load task detail into slide panel
      fetch(taskUrl, {
        headers: {
          "Accept": "text/html"
        }
      })
      .then(response => response.text())
      .then(html => {
        if (this.hasSlidePanelContentTarget) {
          // Extract content from turbo-frame wrapper if present
          const parser = new DOMParser()
          const doc = parser.parseFromString(html, "text/html")
          const frame = doc.querySelector("turbo-frame")
          this.slidePanelContentTarget.innerHTML = frame ? frame.innerHTML : html
          this.openSlidePanel()
        }
      })
    }
  }
}
