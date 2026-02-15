import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "card", "count", "time", "launchButton", "systemStatus", "grid", "modal",
    "editModal", "editForm", "editName", "editDescription", "editIcon", "editModel",
    "editMinutes", "editFrequency", "editCategory", "editEnabled", "editDayCheckbox",
    "editDaysWrap", "createFrequency", "createDaysWrap"
  ]

  connect() {
    this.updateStats()
    this.toggleCreateDays()
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
        this.launchButtonTarget.textContent = "\u2705 ARMED"
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
      this.launchButtonTarget.textContent = `ARM ${n} MISSIONS \uD83D\uDE80`
    } else {
      this.launchButtonTarget.disabled = true
      this.launchButtonTarget.textContent = "SELECT MISSIONS"
    }
  }

  get selectedCards() {
    return this.cardTargets.filter(card => card.classList.contains("selected"))
  }

  openModal() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
  }

  closeModal() {
    this.modalTarget.classList.remove("flex")
    this.modalTarget.classList.add("hidden")
  }

  openEditModal(event) {
    event.stopPropagation()
    const card = event.currentTarget.closest(".ns-card")
    if (!card) return

    const missionId = card.dataset.missionId
    this.editFormTarget.action = `/nightshift/missions/${missionId}`
    this.editNameTarget.value = card.dataset.missionName || ""
    this.editDescriptionTarget.value = card.dataset.missionDescription || ""
    this.editIconTarget.value = card.dataset.missionIcon || ""
    this.editModelTarget.value = card.dataset.missionModel || "gemini"
    this.editMinutesTarget.value = card.dataset.missionTime || 30
    this.editFrequencyTarget.value = card.dataset.missionFrequency || "always"
    this.editCategoryTarget.value = card.dataset.missionCategory || "general"
    this.editEnabledTarget.checked = card.dataset.missionEnabled === "true"

    const selectedDays = (card.dataset.missionDays || "").split(",").filter(Boolean)
    this.editDayCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = selectedDays.includes(checkbox.value)
    })

    this.toggleEditDays()
    this.editModalTarget.classList.remove("hidden")
    this.editModalTarget.classList.add("flex")
  }

  closeEditModal() {
    this.editModalTarget.classList.remove("flex")
    this.editModalTarget.classList.add("hidden")
  }

  toggleCreateDays() {
    if (!this.hasCreateFrequencyTarget || !this.hasCreateDaysWrapTarget) return
    this.createDaysWrapTarget.style.display = this.createFrequencyTarget.value === "weekly" ? "block" : "none"
  }

  toggleEditDays() {
    if (!this.hasEditFrequencyTarget || !this.hasEditDaysWrapTarget) return
    this.editDaysWrapTarget.style.display = this.editFrequencyTarget.value === "weekly" ? "block" : "none"
  }

  overlayClose(event) {
    if (event.target === this.modalTarget) this.closeModal()
  }

  overlayCloseEdit(event) {
    if (event.target === this.editModalTarget) this.closeEditModal()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  filterAll(event) {
    document.querySelectorAll('[data-action*="filterCategory"], [data-action*="filterAll"]').forEach(b => b.classList.remove('active'))
    event.currentTarget.classList.add('active')
    this.cardTargets.forEach(card => card.style.display = '')
  }

  filterCategory(event) {
    const cat = event.currentTarget.dataset.category
    document.querySelectorAll('[data-action*="filterCategory"], [data-action*="filterAll"]').forEach(b => b.classList.remove('active'))
    event.currentTarget.classList.add('active')
    this.cardTargets.forEach(card => {
      card.style.display = card.dataset.missionCategory === cat ? '' : 'none'
    })
  }
}
