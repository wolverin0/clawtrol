import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["overlay", "toggleButton"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  get isOpen() {
    return document.documentElement.classList.contains("sidebar-open")
  }

  toggle(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    document.documentElement.classList.add("sidebar-open")
    localStorage.setItem("sidebar_open", "true")

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden", "opacity-0")
      this.overlayTarget.classList.add("opacity-100")
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    document.documentElement.classList.remove("sidebar-open")
    localStorage.setItem("sidebar_open", "false")

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden", "opacity-0")
      this.overlayTarget.classList.remove("opacity-100")
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", "false")
    }
  }

  handleKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "b") {
      event.preventDefault()
      this.toggle()
    }
  }
}
