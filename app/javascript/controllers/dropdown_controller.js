import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["button", "menu", "container"]

  connect() {
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const isOpen = !this.menuTarget.classList.contains("hidden")
    
    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    // Ensure action container remains visible while open (override hover-only visibility)
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("opacity-0")
      this.containerTarget.classList.add("opacity-100")
      // Lift above neighboring cards' action buttons
      this.containerTarget.classList.add("z-[80]")
    }
    document.addEventListener("click", this.handleClickOutside)
    document.addEventListener("keydown", this.handleKeydown)
  }

  openAtCursor(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // Close any other open dropdowns first
    const isOpen = !this.menuTarget.classList.contains("hidden")
    if (isOpen) {
      return
    }
    
    // Show menu first (but keep it positioned off-screen temporarily to measure)
    const menu = this.menuTarget
    menu.classList.remove("hidden")
    menu.style.visibility = "hidden"
    menu.style.position = "fixed"
    menu.style.left = "0"
    menu.style.top = "0"
    
    // Now we can measure it
    const rect = menu.getBoundingClientRect()
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    
    // Calculate position - try to position near cursor but keep menu in viewport
    let left = event.clientX
    let top = event.clientY
    
    // Adjust if menu would go off right edge
    if (left + rect.width > viewportWidth) {
      left = viewportWidth - rect.width - 8
    }
    
    // Adjust if menu would go off bottom edge
    if (top + rect.height > viewportHeight) {
      top = viewportHeight - rect.height - 8
    }
    
    // Ensure menu doesn't go off left or top edges
    if (left < 8) {
      left = 8
    }
    if (top < 8) {
      top = 8
    }
    
    // Apply final positioning and make visible
    menu.style.left = `${left}px`
    menu.style.top = `${top}px`
    menu.style.right = "auto"
    menu.style.marginTop = "0"
    menu.style.visibility = "visible"
    
    // Complete the open process
    this.buttonTarget.setAttribute("aria-expanded", "true")
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("opacity-0")
      this.containerTarget.classList.add("opacity-100")
      this.containerTarget.classList.add("z-[80]")
    }
    document.addEventListener("click", this.handleClickOutside)
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    // Reset positioning styles for next open (button click will use original positioning)
    const menu = this.menuTarget
    menu.style.position = ""
    menu.style.left = ""
    menu.style.top = ""
    menu.style.right = ""
    menu.style.marginTop = ""
    menu.style.visibility = ""
    // Restore hover-only visibility when closing
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("opacity-100")
      this.containerTarget.classList.add("opacity-0")
      this.containerTarget.classList.remove("z-[80]")
    }
    document.removeEventListener("click", this.handleClickOutside)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}

