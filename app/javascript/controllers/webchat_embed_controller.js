import { Controller } from "@hotwired/stimulus"

// Webchat embed controller — manages the OpenClaw webchat iframe,
// connection status, fullscreen toggle, and context injection.
export default class extends Controller {
  static targets = [
    "iframe", "iframeContainer", "overlay",
    "statusBar", "statusDot", "statusText", "fullscreenBtn"
  ]
  static values = { baseUrl: String, taskId: Number }

  connect() {
    this._checkConnection()
    this._healthInterval = setInterval(() => this._checkConnection(), 30000)
  }

  disconnect() {
    if (this._healthInterval) clearInterval(this._healthInterval)
  }

  reload() {
    if (this.hasIframeTarget) {
      this.iframeTarget.src = this.iframeTarget.src
      this._setStatus("connecting", "Reconnecting...")
    }
  }

  toggleFullscreen() {
    if (!this.hasIframeContainerTarget) return

    const container = this.iframeContainerTarget
    const isFullscreen = container.style.position === "fixed"

    if (isFullscreen) {
      container.style.cssText = "height: 65vh; min-height: 400px;"
      if (this.hasFullscreenBtnTarget) this.fullscreenBtnTarget.textContent = "⤢ Fullscreen"
    } else {
      container.style.cssText = "position: fixed; inset: 0; z-index: 9999; height: 100vh; border-radius: 0;"
      if (this.hasFullscreenBtnTarget) this.fullscreenBtnTarget.textContent = "⤡ Exit Fullscreen"
    }
  }

  injectContext(event) {
    const context = event.currentTarget.dataset.context
    if (!context || !this.hasIframeTarget) return

    // Navigate iframe to webchat with context param
    const url = new URL(this.baseUrlValue)
    url.searchParams.set("context", context)
    this.iframeTarget.src = url.toString()
    this._setStatus("connecting", "Loading with context...")
  }

  // --- Private ---

  async _checkConnection() {
    try {
      // Try to reach the webchat server health
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 5000)

      const res = await fetch(this.baseUrlValue, {
        method: "HEAD",
        mode: "no-cors",
        signal: controller.signal
      })
      clearTimeout(timeout)

      // no-cors HEAD will return opaque response (type: "opaque") if server is up
      this._setStatus("connected", "Connected to webchat")
      if (this.hasOverlayTarget) this.overlayTarget.classList.add("hidden")
    } catch {
      this._setStatus("error", "Webchat unreachable")
      if (this.hasOverlayTarget) this.overlayTarget.classList.remove("hidden")
    }
  }

  _setStatus(state, text) {
    if (!this.hasStatusBarTarget) return

    const colors = {
      connecting: { bar: "border-yellow-500/30 bg-yellow-500/5 text-yellow-400", dot: "text-yellow-400" },
      connected: { bar: "border-green-500/30 bg-green-500/5 text-green-400", dot: "text-green-400" },
      error: { bar: "border-red-500/30 bg-red-500/5 text-red-400", dot: "text-red-400" }
    }

    const c = colors[state] || colors.connecting

    // Reset classes
    this.statusBarTarget.className = `flex items-center gap-2 px-3 py-2 rounded-lg border text-sm transition-colors ${c.bar}`
    if (this.hasStatusDotTarget) this.statusDotTarget.className = c.dot
    if (this.hasStatusTextTarget) this.statusTextTarget.textContent = text
  }
}
