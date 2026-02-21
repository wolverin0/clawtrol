import { Controller } from "@hotwired/stimulus"
import { subscribeToCodemap } from "channels"
import { CodemapRenderer } from "codemap/renderer"

export default class extends Controller {
  static targets = ["canvas", "status"]
  static values = {
    taskId: Number,
    mapId: String,
    debug: { type: Boolean, default: false }
  }

  connect() {
    if (!this.hasCanvasTarget) {
      this.updateStatus("Missing canvas")
      return
    }

    this.renderer = new CodemapRenderer(this.canvasTarget, {
      assetBasePath: "/codemap"
    })
    this.renderer.setDebugOverlay(this.debugValue)
    this.connected = false

    this.setupResizeObserver()
    this.resizeNow()
    this.updateStatus("Connecting...")
    this.startConnectionTimer()

    this.subscription = subscribeToCodemap(this.taskIdValue, this.mapIdValue || String(this.taskIdValue), {
      onInitialized: () => this.updateStatus("Connecting..."),
      onConnected: () => {
        this.connected = true
        this.clearConnectionTimer()
        this.updateStatus("Connected")
      },
      onDisconnected: () => {
        this.connected = false
        this.updateStatus("Disconnected")
      },
      onRejected: (data) => {
        this.connected = false
        this.clearConnectionTimer()
        const reason = data?.reason === "missing_task_id" ? "Missing task" : "Access denied"
        this.updateStatus(reason)
      },
      onReceived: (data) => this.handleMessage(data)
    })

    if (!this.subscription) {
      this.clearConnectionTimer()
      this.updateStatus("Missing task")
    }
  }

  disconnect() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.resizeHandler) window.removeEventListener("resize", this.resizeHandler)
    this.clearConnectionTimer()
    if (this.subscription) this.subscription.unsubscribe()
    if (this.renderer) this.renderer.destroy()
  }

  setupResizeObserver() {
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver((entries) => {
        const entry = entries[0]
        if (!entry || !this.renderer) return
        this.renderer.resize(entry.contentRect.width, entry.contentRect.height)
      })
      this.resizeObserver.observe(this.element)
      return
    }

    this.resizeHandler = () => this.resizeNow()
    window.addEventListener("resize", this.resizeHandler)
  }

  handleMessage(data) {
    if (!this.renderer) return

    if (data.type === "codemap_event") {
      this.renderer.applyEvent(data)
      this.updateStatus("Streaming")
      return
    }

    // also accept direct event envelope for dev convenience
    if (["state_sync", "tile_patch", "sprite_patch", "camera", "selection", "debug_overlay"].includes(data.event)) {
      this.renderer.applyEvent(data)
      this.updateStatus("Streaming")
    }
  }

  toggleDebug() {
    this.debugValue = !this.debugValue
    this.renderer?.setDebugOverlay(this.debugValue)
  }

  resetCamera() {
    this.renderer?.resetCamera()
  }

  updateStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  resizeNow() {
    if (!this.renderer) return
    const rect = this.element.getBoundingClientRect()
    if (!rect.width || !rect.height) return
    this.renderer.resize(rect.width, rect.height)
  }

  startConnectionTimer() {
    this.clearConnectionTimer()
    this.connectionTimer = setTimeout(() => {
      if (!this.connected) this.updateStatus("Waiting for WebSocket")
    }, 4000)
  }

  clearConnectionTimer() {
    if (this.connectionTimer) clearTimeout(this.connectionTimer)
    this.connectionTimer = null
  }
}
