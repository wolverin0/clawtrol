import { Controller } from "@hotwired/stimulus"

/**
 * Sound Toggle Controller - Manages the visual state of the codec sounds toggle switch
 * Works alongside the global sound controller on the body tag
 */
export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.updateToggleVisual()

    // Listen for toggled events from the sound controller
    this.handleToggled = this.handleToggled.bind(this)
    document.addEventListener("sound:toggled", this.handleToggled)
  }

  disconnect() {
    document.removeEventListener("sound:toggled", this.handleToggled)
  }

  handleToggled(event) {
    this.updateToggleVisual()
  }

  updateToggleVisual() {
    const enabled = localStorage.getItem("codecSounds") !== "false"
    const button = this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("[role=switch]")
    if (!button) return

    const knob = button.querySelector("span[aria-hidden]")

    if (enabled) {
      button.classList.add("bg-accent")
      button.classList.remove("bg-bg-elevated")
      button.setAttribute("aria-checked", "true")
      if (knob) knob.classList.add("translate-x-5")
      if (knob) knob.classList.remove("translate-x-0")
    } else {
      button.classList.remove("bg-accent")
      button.classList.add("bg-bg-elevated")
      button.setAttribute("aria-checked", "false")
      if (knob) knob.classList.remove("translate-x-5")
      if (knob) knob.classList.add("translate-x-0")
    }
  }
}
