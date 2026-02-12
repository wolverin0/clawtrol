import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "card", "count", "time", "launchButton", "systemStatus", "grid" ]

  connect() {
    this.updateStats()
  }

  toggle(event) {
    const card = event.currentTarget
    card.classList.toggle("selected")
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
    this.launchButtonTarget.innerHTML = `<span>ARMING...</span>`

    const selectedIds = this.selectedCards.map(card => card.dataset.missionIdParam)
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch('/nightshift/launch', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: JSON.stringify({ mission_ids: selectedIds })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.systemStatusTarget.textContent = `ARMED FOR TONIGHT (${data.armed_count} missions)`
        this.systemStatusTarget.style.color = 'var(--terminal-green)'
        this.launchButtonTarget.innerHTML = `<span>ARMED</span>`
        this.gridTarget.classList.add('armed')
      } else {
        this.launchButtonTarget.innerHTML = `<span>ERROR</span>`
        this.systemStatusTarget.textContent = 'LAUNCH FAILED'
        this.systemStatusTarget.style.color = 'var(--terminal-red)'
      }
    })
    .catch(error => {
      console.error("Launch error:", error)
      this.launchButtonTarget.disabled = false
      this.launchButtonTarget.innerHTML = `<span>ERROR</span>`
      this.systemStatusTarget.textContent = 'NETWORK ERROR'
      this.systemStatusTarget.style.color = 'var(--terminal-red)'
    });
  }

  updateStats() {
    const selectedCount = this.selectedCards.length
    const totalTime = this.selectedCards.reduce((sum, card) => sum + parseInt(card.dataset.missionTimeParam), 0)

    this.countTarget.textContent = selectedCount
    
    if (totalTime < 60) {
      this.timeTarget.textContent = `${totalTime}m`
    } else {
      const h = Math.floor(totalTime / 60)
      const m = totalTime % 60
      this.timeTarget.textContent = `${h}h ${m}m`
    }

    if (selectedCount > 0) {
      this.launchButtonTarget.disabled = false
      this.launchButtonTarget.innerHTML = `<span>ARM ${selectedCount} MISSIONS</span> <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>`
    } else {
      this.launchButtonTarget.disabled = true
      this.launchButtonTarget.innerHTML = `<span>SELECT MISSIONS</span>`
    }
  }

  get selectedCards() {
    return this.cardTargets.filter(card => card.classList.contains("selected"))
  }
}
