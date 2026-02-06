import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="agent-categories"
// Manages the agent personas bar with category groupings
export default class extends Controller {
  static targets = ["category", "dropdown", "badge", "mobileMenu", "toggle"]
  static values = {
    apiBase: { type: String, default: "/api/v1" }
  }

  connect() {
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  toggleCategory(event) {
    const categoryBtn = event.currentTarget
    const categoryName = categoryBtn.dataset.category
    const dropdown = this.dropdownTargets.find(d => d.dataset.category === categoryName)
    
    if (!dropdown) return

    // Close all other dropdowns
    this.dropdownTargets.forEach(d => {
      if (d !== dropdown) {
        d.classList.add("hidden")
        const btn = this.categoryTargets.find(c => c.dataset.category === d.dataset.category)
        if (btn) {
          btn.setAttribute("aria-expanded", "false")
          const chevron = btn.querySelector("[data-chevron]")
          if (chevron) chevron.classList.remove("rotate-180")
        }
      }
    })

    // Toggle this dropdown
    const isOpen = !dropdown.classList.contains("hidden")
    if (isOpen) {
      dropdown.classList.add("hidden")
      categoryBtn.setAttribute("aria-expanded", "false")
      const chevron = categoryBtn.querySelector("[data-chevron]")
      if (chevron) chevron.classList.remove("rotate-180")
    } else {
      dropdown.classList.remove("hidden")
      categoryBtn.setAttribute("aria-expanded", "true")
      const chevron = categoryBtn.querySelector("[data-chevron]")
      if (chevron) chevron.classList.add("rotate-180")
    }
  }

  toggleMobileMenu(event) {
    event.preventDefault()
    const menu = this.mobileMenuTarget
    const toggle = this.toggleTarget
    const isOpen = !menu.classList.contains("hidden")

    if (isOpen) {
      menu.classList.add("hidden")
      toggle.setAttribute("aria-expanded", "false")
    } else {
      menu.classList.remove("hidden")
      toggle.setAttribute("aria-expanded", "true")
    }
  }

  handleClickOutside(event) {
    // Close category dropdowns if clicking outside
    if (!this.element.contains(event.target)) {
      this.dropdownTargets.forEach(d => {
        d.classList.add("hidden")
        const btn = this.categoryTargets.find(c => c.dataset.category === d.dataset.category)
        if (btn) {
          btn.setAttribute("aria-expanded", "false")
          const chevron = btn.querySelector("[data-chevron]")
          if (chevron) chevron.classList.remove("rotate-180")
        }
      })
      
      // Also close mobile menu
      if (this.hasMobileMenuTarget) {
        this.mobileMenuTarget.classList.add("hidden")
        if (this.hasToggleTarget) {
          this.toggleTarget.setAttribute("aria-expanded", "false")
        }
      }
    }
  }

  // Handle drag start for agent badges
  dragStart(event) {
    const badge = event.currentTarget
    event.dataTransfer.setData("application/persona-id", badge.dataset.personaId)
    event.dataTransfer.setData("application/persona-name", badge.dataset.personaName)
    event.dataTransfer.setData("application/persona-emoji", badge.dataset.personaEmoji)
    event.dataTransfer.effectAllowed = "copy"
    
    badge.classList.add("opacity-50", "scale-95")
    
    // Dispatch event to show drop zones on task cards
    document.dispatchEvent(new CustomEvent("persona:drag-start", {
      detail: {
        personaId: badge.dataset.personaId,
        personaName: badge.dataset.personaName
      }
    }))
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-50", "scale-95")
    
    // Dispatch event to hide drop zones
    document.dispatchEvent(new CustomEvent("persona:drag-end"))
  }
}
