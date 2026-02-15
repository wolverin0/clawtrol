import { Controller } from "@hotwired/stimulus"

/**
 * Visual Cron Expression Builder.
 * Handles schedule type switching, cron field editing, and job creation.
 */
export default class extends Controller {
  static targets = ["name", "scheduleType", "cronFields", "intervalFields", "atFields",
                     "cronMinute", "cronHour", "cronDom", "cronMonth", "cronDow", "cronPreview",
                     "intervalValue", "intervalUnit", "atTime",
                     "sessionTarget", "model", "message",
                     "deliverySection", "deliveryMode", "deliveryChannel",
                     "jsonPreview", "status"]

  connect() {
    this.updateScheduleUI()
    this.updateCronPreview()
  }

  updateScheduleUI() {
    const type = this.scheduleTypeTarget.value

    this.cronFieldsTarget.classList.toggle("hidden", type !== "cron")
    this.intervalFieldsTarget.classList.toggle("hidden", type !== "every")
    this.atFieldsTarget.classList.toggle("hidden", type !== "at")
  }

  updatePayloadUI() {
    const target = this.sessionTargetTarget.value
    // Model only relevant for isolated
    if (this.hasModelTarget) {
      this.modelTarget.disabled = (target === "main")
      this.modelTarget.classList.toggle("opacity-50", target === "main")
    }
  }

  updateCronPreview() {
    if (!this.hasCronMinuteTarget) return

    const expr = [
      this.cronMinuteTarget.value || "*",
      this.cronHourTarget.value || "*",
      this.cronDomTarget.value || "*",
      this.cronMonthTarget.value || "*",
      this.cronDowTarget.value || "*"
    ].join(" ")

    this.cronPreviewTarget.textContent = expr
  }

  preview() {
    const job = this.buildJob()
    this.jsonPreviewTarget.textContent = JSON.stringify(job, null, 2)
  }

  async create() {
    const job = this.buildJob()

    if (!job.payload?.text && !job.payload?.message) {
      this.showStatus("Message/prompt is required", "error")
      return
    }

    this.showStatus("Creating cron job...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/cronjobs", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify(job)
      })

      const data = await response.json()
      if (data.ok || data.success) {
        this.showStatus("Job created! Reloading...", "success")
        setTimeout(() => window.location.reload(), 1500)
      } else {
        this.showStatus(data.error || "Creation failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  buildJob() {
    const scheduleType = this.scheduleTypeTarget.value
    const sessionTarget = this.sessionTargetTarget.value
    const message = this.messageTarget.value.trim()
    const model = this.hasModelTarget ? this.modelTarget.value.trim() : ""
    const name = this.nameTarget.value.trim()

    // Build schedule
    let schedule = {}
    if (scheduleType === "cron") {
      const expr = [
        this.cronMinuteTarget.value || "*",
        this.cronHourTarget.value || "*",
        this.cronDomTarget.value || "*",
        this.cronMonthTarget.value || "*",
        this.cronDowTarget.value || "*"
      ].join(" ")
      schedule = { kind: "cron", expr, tz: "America/Buenos_Aires" }
    } else if (scheduleType === "every") {
      const value = parseInt(this.intervalValueTarget.value, 10) || 60
      const unit = this.intervalUnitTarget.value
      const everyMs = unit === "hours" ? value * 3600000 : value * 60000
      schedule = { kind: "every", everyMs }
    } else if (scheduleType === "at") {
      const at = this.atTimeTarget.value
      schedule = { kind: "at", at: at ? new Date(at).toISOString() : new Date().toISOString() }
    }

    // Build payload
    let payload = {}
    if (sessionTarget === "isolated") {
      payload = { kind: "agentTurn", message }
      if (model) payload.model = model
    } else {
      payload = { kind: "systemEvent", text: message }
    }

    // Build delivery
    let delivery = undefined
    if (sessionTarget === "isolated" && this.hasDeliveryModeTarget) {
      delivery = { mode: this.deliveryModeTarget.value }
      const channel = this.hasDeliveryChannelTarget ? this.deliveryChannelTarget.value.trim() : ""
      if (channel) delivery.channel = channel
    }

    const job = { schedule, payload, sessionTarget }
    if (name) job.name = name
    if (delivery) job.delivery = delivery

    return { job }
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = message
    el.classList.remove("hidden", "bg-green-500/20", "text-green-400",
                        "bg-red-500/20", "text-red-400", "bg-blue-500/20", "text-blue-400")
    if (type === "success") el.classList.add("bg-green-500/20", "text-green-400")
    else if (type === "error") el.classList.add("bg-red-500/20", "text-red-400")
    else el.classList.add("bg-blue-500/20", "text-blue-400")
    el.classList.remove("hidden")
    if (type !== "error") setTimeout(() => el.classList.add("hidden"), 5000)
  }
}
