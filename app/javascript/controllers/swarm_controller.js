import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="swarm"
export default class extends Controller {
  static targets = [
    "card",
    "checkbox",
    "selectedCount",
    "totalTime",
    "launchBtn",
    "selectAllBtn",
    "modal",
    "filterBtn"
  ]

  connect() {
    this.selectedIds = new Set()
    this.updateBottomPanel()
  }

  // ─── Selection ───────────────────────────────────────────────────

  toggle(event) {
    const card = event.target.closest("[data-idea-id]")
    if (!card) return

    const id = card.dataset.ideaId
    const checkbox = card.querySelector(".sw-checkbox")

    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id)
      card.classList.remove("sw-selected")
      if (checkbox) checkbox.classList.remove("sw-checked")
    } else {
      this.selectedIds.add(id)
      card.classList.add("sw-selected")
      if (checkbox) checkbox.classList.add("sw-checked")
    }

    this.updateBottomPanel()
  }

  toggleAll() {
    const visibleCards = this.cardTargets.filter(c => c.style.display !== "none")
    const allSelected = visibleCards.every(c => this.selectedIds.has(c.dataset.ideaId))

    if (allSelected) {
      this.deselectAll()
    } else {
      visibleCards.forEach(card => {
        const id = card.dataset.ideaId
        this.selectedIds.add(id)
        card.classList.add("sw-selected")
        const cb = card.querySelector(".sw-checkbox")
        if (cb) cb.classList.add("sw-checked")
      })
    }

    this.updateBottomPanel()
  }

  deselectAll() {
    this.selectedIds.clear()
    this.cardTargets.forEach(card => {
      card.classList.remove("sw-selected")
      const cb = card.querySelector(".sw-checkbox")
      if (cb) cb.classList.remove("sw-checked")
    })
    this.updateBottomPanel()
  }

  // ─── Filters ─────────────────────────────────────────────────────

  filterAll(event) {
    this._setActiveFilter(event.currentTarget)
    this.cardTargets.forEach(card => card.style.display = "")
    this.deselectAll()
  }

  filterCategory(event) {
    const category = event.currentTarget.dataset.category
    this._setActiveFilter(event.currentTarget)

    this.cardTargets.forEach(card => {
      card.style.display = card.dataset.category === category ? "" : "none"
    })
    this.deselectAll()
  }

  filterFavorites(event) {
    this._setActiveFilter(event.currentTarget)

    this.cardTargets.forEach(card => {
      card.style.display = card.dataset.favorite === "true" ? "" : "none"
    })
    this.deselectAll()
  }

  _setActiveFilter(activeBtn) {
    this.filterBtnTargets.forEach(btn => {
      btn.classList.remove("sw-filter-active")
    })
    activeBtn.classList.add("sw-filter-active")
  }

  // ─── Favorites ───────────────────────────────────────────────────

  async toggleFavorite(event) {
    event.stopPropagation()
    const card = event.target.closest("[data-idea-id]")
    if (!card) return

    const id = card.dataset.ideaId
    const starEl = card.querySelector(".sw-star")
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(`/swarm/${id}/toggle_favorite`, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        }
      })

      const data = await response.json()

      if (data.success) {
        card.dataset.favorite = data.favorite ? "true" : "false"
        if (starEl) {
          starEl.textContent = data.favorite ? "\u2605" : "\u2606"
          starEl.classList.toggle("sw-star-active", data.favorite)
        }
      }
    } catch (err) {
      console.error("Toggle favorite failed:", err)
    }
  }

  // ─── Launch ──────────────────────────────────────────────────────

  async launch() {
    if (this.selectedIds.size === 0) return

    const launchBtn = this.launchBtnTarget
    const originalText = launchBtn.textContent
    launchBtn.textContent = "LAUNCHING..."
    launchBtn.disabled = true

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    let successCount = 0
    let errors = []

    for (const id of this.selectedIds) {
      const card = this.cardTargets.find(c => c.dataset.ideaId === id)
      if (!card) continue

      // Read per-card overrides
      const modelSelect = card.querySelector(".sw-model-select")
      const boardSelect = card.querySelector(".sw-board-select")
      const model = modelSelect?.value || ""
      const boardId = boardSelect?.value || ""

      try {
        const response = await fetch(`/swarm/${id}/launch`, {
          method: "POST",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken
          },
          body: JSON.stringify({
            model: model,
            board_id: boardId
          })
        })

        const data = await response.json()

        if (data.success) {
          successCount++
          card.classList.add("sw-launch-success")
        } else {
          errors.push(`${id}: ${data.error}`)
        }
      } catch (err) {
        errors.push(`${id}: ${err.message}`)
      }
    }

    launchBtn.textContent = `LAUNCHED ${successCount}/${this.selectedIds.size}`

    // Brief success display, then reload
    setTimeout(() => {
      window.location.reload()
    }, 1200)
  }

  // ─── Modal ───────────────────────────────────────────────────────

  openModal() {
    const modal = this.modalTarget
    modal.style.display = "flex"
  }

  closeModal() {
    const modal = this.modalTarget
    modal.style.display = "none"
  }

  // Close modal on backdrop click
  backdropClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal()
    }
  }

  // ─── Bottom Panel ────────────────────────────────────────────────

  updateBottomPanel() {
    const count = this.selectedIds.size

    // Selected count
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = count
    }

    // Total estimated time
    if (this.hasTotalTimeTarget) {
      let totalMinutes = 0
      this.selectedIds.forEach(id => {
        const card = this.cardTargets.find(c => c.dataset.ideaId === id)
        if (card) {
          totalMinutes += parseInt(card.dataset.time || "0", 10)
        }
      })

      const hours = Math.floor(totalMinutes / 60)
      const mins = totalMinutes % 60
      this.totalTimeTarget.textContent = hours > 0
        ? `${hours}h ${mins}m`
        : `${mins}m`
    }

    // Launch button state
    if (this.hasLaunchBtnTarget) {
      this.launchBtnTarget.disabled = count === 0
      this.launchBtnTarget.textContent = count > 0
        ? `LAUNCH ${count} IDEA${count !== 1 ? "S" : ""}`
        : "LAUNCH"
    }
  }
}
