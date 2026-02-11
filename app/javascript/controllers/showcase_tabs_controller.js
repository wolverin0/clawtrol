import { Controller } from "@hotwired/stimulus"

// Switches showcase preview iframe src when clicking variant tabs
export default class extends Controller {
  static targets = ["tab", "frame"]

  connect() {
    this.currentIndex = 0
  }

  switchTab(event) {
    event.preventDefault()
    const button = event.currentTarget
    const index = parseInt(button.dataset.index, 10)
    const fileUrl = button.dataset.url

    if (index === this.currentIndex) return

    // Update tab styles
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.remove("bg-bg-elevated", "text-content-muted", "border", "border-border")
        tab.classList.add("bg-accent", "text-white")
      } else {
        tab.classList.remove("bg-accent", "text-white")
        tab.classList.add("bg-bg-elevated", "text-content-muted", "border", "border-border")
      }
    })

    // Swap iframe src
    this.frameTarget.src = fileUrl

    this.currentIndex = index
  }
}
