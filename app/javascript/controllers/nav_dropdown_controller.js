import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav-dropdown"
export default class extends Controller {
  static targets = ["menu", "button", "chevron"]

  connect() {
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleCloseAll = this.handleCloseAll.bind(this)

    document.addEventListener("nav-dropdown:close-all", this.handleCloseAll)
  }

  disconnect() {
    document.removeEventListener("nav-dropdown:close-all", this.handleCloseAll)
    document.removeEventListener("click", this.handleClickOutside)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    document.dispatchEvent(new CustomEvent("nav-dropdown:close-all", { detail: { except: this.element } }))

    this.menuTarget.classList.remove("hidden")
    this.setExpanded(true)
    this.applyOpenState(true)

    document.addEventListener("click", this.handleClickOutside)
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    if (!this.isOpen) return

    this.menuTarget.classList.add("hidden")
    this.setExpanded(false)
    this.applyOpenState(false)

    document.removeEventListener("click", this.handleClickOutside)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleCloseAll(event) {
    if (event.detail?.except !== this.element) {
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

  setExpanded(expanded) {
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", expanded.toString())
    }
  }

  applyOpenState(open) {
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180", open)
    }

    if (this.hasButtonTarget && !this.isActive) {
      this.buttonTarget.classList.toggle("bg-bg-elevated", open)
      this.buttonTarget.classList.toggle("text-content", open)
    }
  }

  get isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  get isActive() {
    return this.hasButtonTarget && this.buttonTarget.dataset.navDropdownActive === "true"
  }
}
