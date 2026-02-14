import { Controller } from "@hotwired/stimulus"

// Controls expand/collapse of agent chat messages and auto-scroll
export default class extends Controller {
  static targets = ["container", "truncated", "full"]
  static values = { taskId: Number }

  connect() {
    this.scrollToBottom()
  }

  scrollToBottom() {
    const container = this.containerTarget
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  }

  expand(event) {
    const messageId = event.currentTarget.dataset.messageId
    this.truncatedTargets.forEach(el => {
      if (el.dataset.messageId === messageId) el.classList.add("hidden")
    })
    this.fullTargets.forEach(el => {
      if (el.dataset.messageId === messageId) el.classList.remove("hidden")
    })
  }

  collapse(event) {
    const messageId = event.currentTarget.dataset.messageId
    this.truncatedTargets.forEach(el => {
      if (el.dataset.messageId === messageId) el.classList.remove("hidden")
    })
    this.fullTargets.forEach(el => {
      if (el.dataset.messageId === messageId) el.classList.add("hidden")
    })
  }
}
