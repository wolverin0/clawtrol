import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    themes: { type: Array, default: ["default", "light", "vaporwave"] }
  }

  connect() {
    const saved = localStorage.getItem("clawtrol-theme")
    if (saved && this.themesValue.includes(saved)) {
      document.body.setAttribute("data-theme", saved)
    }
    // Restore CRT scanline preference
    if (localStorage.getItem("clawtrol-no-scanlines") === "true") {
      document.body.classList.add("no-scanlines")
    }
    // Restore CRT flicker preference
    if (localStorage.getItem("clawtrol-crt-flicker") === "true") {
      document.body.classList.add("crt-flicker")
    }
    this.updateLabel()
  }

  toggle() {
    const current = document.body.getAttribute("data-theme") || "default"
    const idx = this.themesValue.indexOf(current)
    const next = this.themesValue[(idx + 1) % this.themesValue.length]

    document.body.setAttribute("data-theme", next)
    localStorage.setItem("clawtrol-theme", next)
    this.updateLabel()
    this.saveToServer(next)
  }

  updateLabel() {
    const theme = document.body.getAttribute("data-theme") || "default"
    const icons = { default: "\uD83C\uDF19", light: "\u2600\uFE0F", vaporwave: "\uD83C\uDF08" }
    const labels = { default: "Dark", light: "Light", vaporwave: "Vapor" }

    const iconEl = this.element.querySelector("[data-theme-icon]")
    const labelEl = this.element.querySelector("[data-theme-label]")

    if (iconEl) iconEl.textContent = icons[theme] || "\uD83C\uDFA8"
    if (labelEl) labelEl.textContent = labels[theme] || theme
  }

  toggleScanlines() {
    const off = document.body.classList.toggle("no-scanlines")
    localStorage.setItem("clawtrol-no-scanlines", off.toString())
  }

  toggleFlicker() {
    const on = document.body.classList.toggle("crt-flicker")
    localStorage.setItem("clawtrol-crt-flicker", on.toString())
  }

  async saveToServer(theme) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      await fetch("/settings", {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ user: { theme: theme } }),
        credentials: "same-origin"
      })
    } catch (_e) {
      // Silently fail - localStorage is the primary store
    }
  }
}
