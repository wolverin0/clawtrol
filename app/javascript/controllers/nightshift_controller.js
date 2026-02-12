import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "card", "count", "time", "launchButton", "systemStatus", "grid" ]

  connect() {
    this.updateStats()
  }

  toggle(event) {
    event.currentTarget.classList.toggle("selected")
    this.updateStats()
  }

  toggleAll() {
    const isAllSelected = this.selectedCards.length === this.cardTargets.length
    this.cardTargets.forEach(card => {
      card.classList.toggle("selected", !isAllSelected)
    })
    this.updateStats()
  }

  launch() {
    this.launchButtonTarget.disabled = true
    this.launchButtonTarget.textContent = "ARMING..."

    const selectedIds = this.selectedCards.map(card => parseInt(card.dataset.missionId))
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    fetch('/nightshift/launch', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken || '',
        'Accept': 'application/json'
      },
      body: JSON.stringify({ mission_ids: selectedIds })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.systemStatusTarget.textContent = `ARMED (${data.armed_count} missions)`
        this.systemStatusTarget.style.color = 'var(--terminal-green)'
        this.launchButtonTarget.textContent = "✅ ARMED"
      } else {
        this.launchButtonTarget.textContent = "ERROR"
      }
    })
    .catch(() => {
      this.launchButtonTarget.disabled = false
      this.launchButtonTarget.textContent = "RETRY"
    })
  }

  updateStats() {
    const n = this.selectedCards.length
    const t = this.selectedCards.reduce((sum, card) => sum + parseInt(card.dataset.missionTime), 0)

    this.countTarget.textContent = n
    this.timeTarget.textContent = t < 60 ? `${t}m` : `${Math.floor(t/60)}h ${t%60}m`

    if (n > 0) {
      this.launchButtonTarget.disabled = false
      this.launchButtonTarget.textContent = `ARM ${n} MISSIONS 🚀`
    } else {
      this.launchButtonTarget.disabled = true
      this.launchButtonTarget.textContent = "SELECT MISSIONS"
    }
  }

  get selectedCards() {
    return this.cardTargets.filter(card => card.classList.contains("selected"))
  }
}
