import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "count", "time", "launchButton", "grid", "modal"]

  connect() {
    this.updateStats()
  }

  toggle(event) {
    const card = event.currentTarget
    card.classList.toggle("selected")
    const checkbox = card.querySelector(".sw-checkbox")
    if (checkbox) {
      const isSelected = card.classList.contains("selected")
      checkbox.classList.toggle("border-emerald-400", isSelected)
      checkbox.classList.toggle("bg-emerald-400", isSelected)
      checkbox.querySelector("span").style.opacity = isSelected ? "1" : "0"
    }
    this.updateStats()
  }

  toggleAll() {
    const allSelected = this.selectedCards.length === this.visibleCards.length
    this.visibleCards.forEach(card => {
      card.classList.toggle("selected", !allSelected)
      const checkbox = card.querySelector(".sw-checkbox")
      if (checkbox) {
        checkbox.classList.toggle("border-emerald-400", !allSelected)
        checkbox.classList.toggle("bg-emerald-400", !allSelected)
        checkbox.querySelector("span").style.opacity = !allSelected ? "1" : "0"
      }
    })
    this.updateStats()
  }

  deselectAll() {
    this.cardTargets.forEach(card => {
      card.classList.remove("selected")
      const checkbox = card.querySelector(".sw-checkbox")
      if (checkbox) {
        checkbox.classList.remove("border-emerald-400", "bg-emerald-400")
        checkbox.querySelector("span").style.opacity = "0"
      }
    })
    this.updateStats()
  }

  filterCategory(event) {
    const cat = event.currentTarget.dataset.category
    // Toggle active state on buttons
    this.element.querySelectorAll("[data-action*='filterCategory'], [data-action*='filterAll']").forEach(b => b.classList.remove("active", "border-sky-400", "text-sky-400"))
    event.currentTarget.classList.add("active", "border-sky-400", "text-sky-400")

    this.cardTargets.forEach(card => {
      card.style.display = (!cat || card.dataset.category === cat) ? "" : "none"
    })
    this.updateStats()
  }

  filterAll(event) {
    this.element.querySelectorAll("[data-action*='filterCategory'], [data-action*='filterAll']").forEach(b => b.classList.remove("active", "border-sky-400", "text-sky-400"))
    event.currentTarget.classList.add("active", "border-sky-400", "text-sky-400")
    this.cardTargets.forEach(card => card.style.display = "")
    this.updateStats()
  }

  launch() {
    const selected = this.selectedCards
    if (selected.length === 0) return

    this.launchButtonTarget.disabled = true
    this.launchButtonTarget.textContent = "LAUNCHING..."

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const promises = selected.map(card => {
      const id = card.dataset.ideaId
      const modelSelect = card.querySelector(".sw-model-select")
      const model = modelSelect ? modelSelect.value : ""
      return fetch(`/swarm/launch/${id}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken || "",
          "Accept": "text/html"
        },
        body: model ? `model=${encodeURIComponent(model)}` : "",
        redirect: "follow"
      })
    })

    Promise.all(promises).then(() => {
      window.location.reload()
    }).catch(() => {
      this.launchButtonTarget.disabled = false
      this.launchButtonTarget.textContent = "RETRY"
    })
  }

  openModal() {
    this.modalTarget.style.display = "flex"
  }

  closeModal() {
    this.modalTarget.style.display = "none"
  }

  overlayClose(event) {
    if (event.target === this.modalTarget) this.closeModal()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  updateStats() {
    const selected = this.selectedCards
    const n = selected.length
    const t = selected.reduce((sum, card) => sum + parseInt(card.dataset.time || 0), 0)

    if (this.hasCountTarget) this.countTarget.textContent = n
    if (this.hasTimeTarget) this.timeTarget.textContent = t < 60 ? `${t}m` : `${Math.floor(t / 60)}h ${t % 60}m`

    if (this.hasLaunchButtonTarget) {
      if (n > 0) {
        this.launchButtonTarget.disabled = false
        this.launchButtonTarget.textContent = `🚀 LAUNCH ${n} IDEA${n > 1 ? "S" : ""}`
      } else {
        this.launchButtonTarget.disabled = true
        this.launchButtonTarget.textContent = "SELECT IDEAS"
      }
    }
  }

  get selectedCards() {
    return this.cardTargets.filter(card => card.classList.contains("selected"))
  }

  get visibleCards() {
    return this.cardTargets.filter(card => card.style.display !== "none")
  }
}
