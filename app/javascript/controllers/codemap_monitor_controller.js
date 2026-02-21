import { Controller } from "@hotwired/stimulus"
import { subscribeToKanban } from "channels"
import { CodemapHotelRenderer } from "codemap/hotel_renderer"

const VIEW_STORAGE_KEY = "codemapMonitorView"
const ACTIVE_CLASSES = ["bg-accent/20", "text-accent", "border-accent/40"]
const INACTIVE_CLASSES = ["bg-bg-surface", "text-content-muted", "border-border"]

export default class extends Controller {
  static targets = ["hotelCanvas", "hotelPanel", "techPanel", "hotelToggle", "techToggle", "hotelFrame"]
  static values = {
    tasks: Array
  }

  connect() {
    this.tasks = Array.isArray(this.tasksValue) ? this.tasksValue : []
    this.subscriptions = []

    if (this.hasHotelCanvasTarget) {
      this.renderer = new CodemapHotelRenderer(this.hotelCanvasTarget, {
        assetBasePath: "/codemap"
      })
      this.renderer.setTasks(this.tasks)
      this.setupResizeObserver()
      this.setupPointerHandlers()
      this.resizeNow()
    }

    this.connectKanban()
    const saved = window.localStorage?.getItem(VIEW_STORAGE_KEY)
    this.setMode(saved || "hotel")
  }

  disconnect() {
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.resizeHandler) window.removeEventListener("resize", this.resizeHandler)
    if (this.pointerMoveHandler) this.hotelCanvasTarget?.removeEventListener("mousemove", this.pointerMoveHandler)
    if (this.pointerLeaveHandler) this.hotelCanvasTarget?.removeEventListener("mouseleave", this.pointerLeaveHandler)
    if (this.pointerClickHandler) this.hotelCanvasTarget?.removeEventListener("click", this.pointerClickHandler)
    this.subscriptions.forEach((subscription) => subscription.unsubscribe())
    this.subscriptions = []
    this.renderer?.destroy()
  }

  showHotel() {
    this.setMode("hotel")
  }

  showTech() {
    this.setMode("tech")
  }

  setMode(mode) {
    const nextMode = mode === "tech" ? "tech" : "hotel"
    if (this.hasHotelPanelTarget) this.hotelPanelTarget.classList.toggle("hidden", nextMode === "tech")
    if (this.hasTechPanelTarget) this.techPanelTarget.classList.toggle("hidden", nextMode === "hotel")

    if (this.hasHotelToggleTarget) this.setToggleState(this.hotelToggleTarget, nextMode === "hotel")
    if (this.hasTechToggleTarget) this.setToggleState(this.techToggleTarget, nextMode === "tech")

    window.localStorage?.setItem(VIEW_STORAGE_KEY, nextMode)
  }

  setToggleState(button, active) {
    const add = active ? ACTIVE_CLASSES : INACTIVE_CLASSES
    const remove = active ? INACTIVE_CLASSES : ACTIVE_CLASSES

    add.forEach((cls) => button.classList.add(cls))
    remove.forEach((cls) => button.classList.remove(cls))
  }

  connectKanban() {
    const boardIds = Array.from(new Set(this.tasks.map((task) => task.board_id).filter(Boolean)))
    boardIds.forEach((boardId) => {
      const subscription = subscribeToKanban(boardId, {
        onReceived: (data) => this.handleKanbanMessage(data)
      })
      if (subscription) this.subscriptions.push(subscription)
    })
  }

  handleKanbanMessage(data) {
    if (!data || !this.renderer) return
    if (data.type === "destroy" && data.task_id) {
      this.renderer.removeTask(data.task_id)
      return
    }

    if (!data.task_id || !data.new_status) return
    this.renderer.updateTaskStatus(data.task_id, data.new_status)
  }

  setupResizeObserver() {
    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver((entries) => {
        const entry = entries[0]
        if (!entry || !this.renderer) return
        this.renderer.resize(entry.contentRect.width, entry.contentRect.height)
      })
      this.resizeObserver.observe(this.hotelFrameTarget)
      return
    }

    this.resizeHandler = () => this.resizeNow()
    window.addEventListener("resize", this.resizeHandler)
  }

  resizeNow() {
    if (!this.renderer) return
    const rect = this.hotelFrameTarget?.getBoundingClientRect()
    if (!rect || !rect.width || !rect.height) return
    this.renderer.resize(rect.width, rect.height)
  }

  setupPointerHandlers() {
    if (!this.renderer) return
    this.pointerMoveHandler = (event) => this.handlePointerMove(event)
    this.pointerLeaveHandler = () => this.handlePointerLeave()
    this.pointerClickHandler = (event) => this.handlePointerClick(event)
    this.hotelCanvasTarget.addEventListener("mousemove", this.pointerMoveHandler)
    this.hotelCanvasTarget.addEventListener("mouseleave", this.pointerLeaveHandler)
    this.hotelCanvasTarget.addEventListener("click", this.pointerClickHandler)
  }

  handlePointerMove(event) {
    if (!this.renderer) return
    const hit = this.pickTask(event)
    this.hotelCanvasTarget.style.cursor = hit ? "pointer" : "default"
    this.renderer.setHoveredTask(hit?.id || null)
  }

  handlePointerLeave() {
    if (!this.renderer) return
    this.hotelCanvasTarget.style.cursor = "default"
    this.renderer.setHoveredTask(null)
  }

  handlePointerClick(event) {
    if (!this.renderer) return
    const hit = this.pickTask(event)
    if (hit?.url && hit.url !== "#") window.location.assign(hit.url)
  }

  pickTask(event) {
    const rect = this.hotelCanvasTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    return this.renderer.pickTaskAt(x, y)
  }
}
