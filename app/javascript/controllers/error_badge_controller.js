import { Controller } from "@hotwired/stimulus"

// Polls for errored task count and displays badge in header
export default class extends Controller {
  static targets = ["button", "count"]
  static values = {
    url: String,
    boardId: Number,
    interval: { type: Number, default: 30000 }
  }

  connect() {
    this.fetchCount()
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.fetchCount(), this.intervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
    }
  }

  async fetchCount() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        this.updateBadge(data.count)
      }
    } catch (error) {
      console.error('Error fetching errored task count:', error)
    }
  }

  updateBadge(count) {
    if (count > 0) {
      this.buttonTarget.classList.remove('hidden')
      this.countTarget.textContent = count
    } else {
      this.buttonTarget.classList.add('hidden')
    }
  }

  filterErrors() {
    // Navigate to board with error filter
    // For now, just reload the page - in a more advanced version,
    // we could use Turbo to filter the board view
    const url = new URL(window.location.href)
    url.searchParams.set('filter', 'errored')
    window.location.href = url.toString()
  }
}
