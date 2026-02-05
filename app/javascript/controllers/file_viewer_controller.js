import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-viewer"
// Manages the file viewer panel within the task modal
export default class extends Controller {
  static targets = ["panel", "content"]

  connect() {
    // Listen for turbo:frame-load to show panel when file content loads
    this.element.addEventListener("turbo:frame-load", this.onFrameLoad.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.onFrameLoad.bind(this))
  }

  open(event) {
    event.preventDefault()
    // The link has data-turbo-frame="file_viewer" which loads content into the frame
    // Show the panel
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
    }
  }

  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
      // Clear the turbo frame content
      const frame = this.panelTarget.querySelector("turbo-frame")
      if (frame) {
        frame.innerHTML = ""
      }
    }
  }

  onFrameLoad() {
    // When turbo frame loads content, ensure panel is visible
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
    }
  }
}
