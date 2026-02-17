import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "error", "list", "empty", "summary", "count"]

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 15000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    try {
      const response = await fetch("/cronjobs.json", {
        headers: { "Accept": "application/json" }
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        throw new Error(data?.error || `HTTP ${response.status}`)
      }

      this.render(data)
    } catch (e) {
      console.error("cronjobs refresh error", e)
      this.setOfflineState(e?.message)
    }
  }

  setOfflineState(message) {
    this.statusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-red-500/10 text-red-400 text-xs font-medium border border-red-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>
        OFFLINE
      </span>
    `

    if (message) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  render(data) {
    if (data.status !== "online") {
      this.setOfflineState(data.error || "Gateway offline")
      return
    }

    this.errorTarget.classList.add("hidden")

    this.statusTarget.innerHTML = `
      <span class="inline-flex items-center gap-2 px-2 py-1 rounded-full bg-green-500/10 text-green-400 text-xs font-medium border border-green-500/20">
        <span class="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
        ONLINE
      </span>
    `

    const jobs = Array.isArray(data.jobs) ? data.jobs : []

    if (this.hasCountTarget) {
      this.countTarget.textContent = jobs.length > 0 ? jobs.length : ""
    }

    const enabledCount = jobs.filter(j => j.enabled).length
    const disabledCount = jobs.length - enabledCount

    this.summaryTarget.innerHTML = `
      <div class="flex justify-between items-center text-sm">
        <span class="text-muted">Total</span>
        <span class="font-mono">${jobs.length}</span>
      </div>
      <div class="flex justify-between items-center text-sm">
        <span class="text-muted">Enabled</span>
        <span class="font-mono text-green-300">${enabledCount}</span>
      </div>
      <div class="flex justify-between items-center text-sm">
        <span class="text-muted">Disabled</span>
        <span class="font-mono text-gray-300">${disabledCount}</span>
      </div>
      <div class="pt-2 text-[10px] text-muted/70">Updated: ${this.formatTime(data.generatedAt)}</div>
    `

    if (jobs.length === 0) {
      this.listTarget.innerHTML = ""
      this.emptyTarget.classList.remove("hidden")
      return
    }

    this.emptyTarget.classList.add("hidden")

    // Sort enabled first, then by name.
    jobs.sort((a, b) => {
      if (!!a.enabled !== !!b.enabled) return a.enabled ? -1 : 1
      return String(a.name || "").localeCompare(String(b.name || ""))
    })

    this.listTarget.innerHTML = jobs.map(job => this.buildJobCard(job)).join("")
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  }

  async toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const btn = event.currentTarget
    const id = btn?.dataset?.id
    const enabled = btn?.dataset?.enabled === "true"
    const desired = (!enabled)

    if (!id) return

    btn.disabled = true
    btn.textContent = desired ? "ENABLING…" : "DISABLING…"

    try {
      const res = await fetch(`/cronjobs/${encodeURIComponent(id)}/toggle`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken() || ""
        },
        body: JSON.stringify({ enabled: desired })
      })

      const data = await res.json().catch(() => ({}))
      if (!res.ok || data.ok === false) throw new Error(data.error || "Toggle failed")

      await this.refresh()
    } catch (e) {
      console.error("toggle failed", e)
      this.errorTarget.textContent = e?.message || "Toggle failed"
      this.errorTarget.classList.remove("hidden")
      btn.disabled = false
      btn.textContent = enabled ? "Disable" : "Enable"
    }
  }

  async runNow(event) {
    event.preventDefault()
    event.stopPropagation()

    const btn = event.currentTarget
    const id = btn?.dataset?.id
    if (!id) return

    btn.disabled = true
    const original = btn.textContent
    btn.textContent = "RUNNING…"

    try {
      const res = await fetch(`/cronjobs/${encodeURIComponent(id)}/run`, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken() || ""
        }
      })

      const data = await res.json().catch(() => ({}))
      if (!res.ok || data.ok === false) throw new Error(data.error || "Run failed")

      btn.textContent = "QUEUED"
      window.setTimeout(() => {
        btn.disabled = false
        btn.textContent = original
      }, 800)

      // refresh soon to get last run status
      window.setTimeout(() => this.refresh(), 1500)
    } catch (e) {
      console.error("run failed", e)
      this.errorTarget.textContent = e?.message || "Run failed"
      this.errorTarget.classList.remove("hidden")
      btn.disabled = false
      btn.textContent = original
    }
  }

  editJob(event) {
    event.preventDefault()
    event.stopPropagation()

    const jobJson = event.currentTarget?.dataset?.job
    if (!jobJson) return

    let job
    try {
      job = JSON.parse(jobJson)
    } catch {
      return
    }

    const builder = document.querySelector('[data-controller="cron-builder"]')
    const details = builder?.querySelector("details") || builder?.closest("details")
    if (details) details.open = true

    if (builder) {
      builder.dispatchEvent(new CustomEvent("cron-builder:load", { detail: job }))
    }
  }

  copyId(event) {
    const el = event.currentTarget
    const id = el?.dataset?.id
    if (!id) return

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(id).catch(() => {})
    }

    el.classList.add("ring", "ring-accent/30")
    window.setTimeout(() => el.classList.remove("ring", "ring-accent/30"), 350)
  }

  buildJobCard(job) {
    const enabled = !!job.enabled
    const statusBadge = enabled
      ? "bg-green-500/10 text-green-400 border border-green-500/20"
      : "bg-gray-500/10 text-gray-400 border border-gray-500/20"

    const lastStatus = job.lastStatus ? String(job.lastStatus).toUpperCase() : "—"
    const lastStatusColor = job.lastStatus === "ok"
      ? "text-green-400"
      : (job.lastStatus === "error" ? "text-red-400" : "text-muted")

    const safeName = this.escapeHtml(job.name || job.id)
    const scheduleText = this.escapeHtml(job.scheduleText || "")
    const nextRun = this.formatTime(job.nextRunAt)
    const rawJobData = JSON.stringify({
      id: job.id,
      name: job.name,
      schedule: job.schedule,
      sessionTarget: job.sessionTarget,
      delivery: job.delivery,
      payload: job.payload
    })

    return `
      <div class="bg-card border border-border rounded-lg p-4 flex flex-col gap-3 shadow-sm hover:border-accent/50 transition-colors" data-action="click->cronjobs#copyId" data-id="${this.escapeAttr(job.id)}">
        <div class="flex justify-between items-start gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <h3 class="font-medium text-text truncate" title="${safeName}">${safeName}</h3>
            </div>
            <div class="text-xs text-muted font-mono truncate" title="${this.escapeAttr(job.id)}">${this.escapeHtml(job.id)}</div>
          </div>

          <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${statusBadge}">
            ${enabled ? "ENABLED" : "DISABLED"}
          </span>
        </div>

        <div class="space-y-1 text-xs">
          <div class="flex justify-between gap-2">
            <span class="text-muted">Schedule</span>
            <span class="text-text font-mono text-right truncate" title="${scheduleText}">${scheduleText}</span>
          </div>
          <div class="flex justify-between gap-2">
            <span class="text-muted">Next</span>
            <span class="text-text font-mono">${this.escapeHtml(nextRun)}</span>
          </div>
          <div class="flex justify-between gap-2">
            <span class="text-muted">Last</span>
            <span class="font-mono ${lastStatusColor}">${this.escapeHtml(lastStatus)}</span>
          </div>
        </div>

        <div class="flex gap-2 pt-1">
          <button type="button"
                  class="flex-1 text-xs px-3 py-2 rounded-md border border-border bg-white/5 hover:bg-white/10 transition-colors"
                  data-action="click->cronjobs#runNow"
                  data-id="${this.escapeAttr(job.id)}">
            Run Now
          </button>

          <button type="button"
                  class="flex-1 text-xs px-3 py-2 rounded-md border border-border bg-white/5 hover:bg-white/10 transition-colors"
                  data-action="click->cronjobs#editJob"
                  data-id="${this.escapeAttr(job.id)}"
                  data-job='${this.escapeAttr(rawJobData)}'>
            Edit
          </button>

          <button type="button"
                  class="flex-1 text-xs px-3 py-2 rounded-md border border-border ${enabled ? "bg-red-500/10 hover:bg-red-500/20 text-red-200" : "bg-green-500/10 hover:bg-green-500/20 text-green-200"} transition-colors"
                  data-action="click->cronjobs#toggle"
                  data-id="${this.escapeAttr(job.id)}"
                  data-enabled="${enabled}">
            ${enabled ? "Disable" : "Enable"}
          </button>
        </div>
      </div>
    `
  }

  formatTime(iso) {
    if (!iso) return "—"
    try {
      const d = new Date(iso)
      return d.toLocaleString([], { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" })
    } catch {
      return String(iso)
    }
  }

  escapeHtml(str) {
    return String(str || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }

  escapeAttr(str) {
    // minimal attribute escaping — must handle single AND double quotes
    return this.escapeHtml(str).replace(/`/g, "&#096;").replace(/'/g, "&#39;")
  }
}
