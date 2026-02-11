import { Controller } from "@hotwired/stimulus"

// Handles product and winner filtering for the Showcase gallery
// Filters cards by product tag or winner status without page reload
export default class extends Controller {
  static targets = ["filterBtn", "winnersBtn", "card", "weekSection"]
  static values = { 
    product: { type: String, default: "all" },
    winnersOnly: { type: Boolean, default: false }
  }

  connect() {
    // Initialize with "all" selected
    this.productValue = "all"
    this.winnersOnlyValue = false
    this.updateButtonStates()
  }

  filter(event) {
    const button = event.currentTarget
    const product = button.dataset.product
    
    this.productValue = product
    this.winnersOnlyValue = false
    this.updateButtonStates()
    this.filterCards()
  }

  filterWinners(event) {
    this.winnersOnlyValue = !this.winnersOnlyValue
    if (this.winnersOnlyValue) {
      this.productValue = null // Clear product filter when showing winners
    } else {
      this.productValue = "all"
    }
    this.updateButtonStates()
    this.filterCards()
  }

  updateButtonStates() {
    // Update product filter buttons
    this.filterBtnTargets.forEach(btn => {
      // Skip winners button - handled separately
      if (this.hasWinnersBtnTarget && btn === this.winnersBtnTarget) return
      
      const isActive = !this.winnersOnlyValue && btn.dataset.product === this.productValue
      
      if (isActive) {
        btn.classList.remove("bg-bg-elevated", "border", "border-border", "text-content-secondary")
        btn.classList.add("bg-accent", "text-white")
      } else {
        btn.classList.add("bg-bg-elevated", "border", "border-border", "text-content-secondary")
        btn.classList.remove("bg-accent", "text-white")
      }
    })
    
    // Update winners button
    if (this.hasWinnersBtnTarget) {
      if (this.winnersOnlyValue) {
        this.winnersBtnTarget.classList.remove("bg-yellow-500/20", "border-yellow-500/50", "text-yellow-400")
        this.winnersBtnTarget.classList.add("bg-yellow-500", "text-black", "border-yellow-500")
      } else {
        this.winnersBtnTarget.classList.add("bg-yellow-500/20", "border-yellow-500/50", "text-yellow-400")
        this.winnersBtnTarget.classList.remove("bg-yellow-500", "text-black", "border-yellow-500")
      }
    }
  }

  filterCards() {
    const selectedProduct = this.productValue
    const showWinnersOnly = this.winnersOnlyValue
    
    // Filter individual cards
    this.cardTargets.forEach(card => {
      const cardProduct = card.dataset.product
      const isWinner = card.dataset.winner === "true"
      
      let shouldShow = true
      
      // Check winner filter
      if (showWinnersOnly && !isWinner) {
        shouldShow = false
      }
      
      // Check product filter (only if not in winners-only mode)
      if (!showWinnersOnly && selectedProduct && selectedProduct !== "all" && cardProduct !== selectedProduct) {
        shouldShow = false
      }
      
      if (shouldShow) {
        card.classList.remove("hidden")
      } else {
        card.classList.add("hidden")
      }
    })

    // Hide week sections that have no visible cards
    this.weekSectionTargets.forEach(section => {
      const visibleCards = section.querySelectorAll('[data-showcase-filter-target="card"]:not(.hidden)')
      
      if (visibleCards.length === 0) {
        section.classList.add("hidden")
      } else {
        section.classList.remove("hidden")
      }
    })
  }
}
