import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for Identity Links management.
 * Handles CRUD on link groups and saves to gateway config.
 */
export default class extends Controller {
  static targets = ["groupsList", "jsonPreview", "status", "count",
                     "editModal", "identityInputs", "emptyState"]

  connect() {
    this.groups = this.loadGroupsFromDOM()
    this.updatePreview()
  }

  loadGroupsFromDOM() {
    const items = this.groupsListTarget.querySelectorAll("[data-group-index]")
    return Array.from(items).map(el => {
      const identities = el.querySelectorAll(".font-mono.text-accent")
      const channels = el.querySelectorAll(".font-mono.text-content")
      const group = []
      channels.forEach((chEl, i) => {
        const channel = chEl.textContent.replace(":", "").trim()
        const id = identities[i]?.textContent?.trim() || ""
        if (channel && id) group.push(`${channel}:${id}`)
      })
      return group
    }).filter(g => g.length >= 2)
  }

  addGroup() {
    this.editModalTarget.classList.remove("hidden")
    const inputs = this.identityInputsTarget
    // Reset inputs
    inputs.querySelectorAll("input[data-identity-id]").forEach(i => i.value = "")
  }

  closeModal() {
    this.editModalTarget.classList.add("hidden")
  }

  addIdentityRow() {
    const container = this.identityInputsTarget
    const firstRow = container.querySelector(".flex.gap-2")
    if (!firstRow) return

    const newRow = firstRow.cloneNode(true)
    newRow.querySelector("input").value = ""
    container.appendChild(newRow)
  }

  applyGroup() {
    const rows = this.identityInputsTarget.querySelectorAll(".flex.gap-2")
    const group = []

    rows.forEach(row => {
      const channel = row.querySelector("select[data-identity-channel]")?.value || ""
      const id = row.querySelector("input[data-identity-id]")?.value?.trim() || ""
      if (channel && id) group.push(`${channel}:${id}`)
    })

    if (group.length < 2) {
      this.showStatus("Need at least 2 identities in a group", "error")
      return
    }

    this.groups.push(group)
    this.closeModal()
    this.renderGroups()
    this.updatePreview()
  }

  removeGroup(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (index < 0 || index >= this.groups.length) return
    if (!confirm("Remove this identity link group?")) return

    this.groups.splice(index, 1)
    this.renderGroups()
    this.updatePreview()
  }

  async saveAll() {
    this.showStatus("Saving identity links...", "info")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/identity_links/save", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ links_json: JSON.stringify(this.groups) })
      })

      const data = await response.json()
      if (data.success) {
        this.showStatus(data.message || "Saved!", "success")
      } else {
        this.showStatus(data.error || "Save failed", "error")
      }
    } catch (err) {
      this.showStatus(`Error: ${err.message}`, "error")
    }
  }

  renderGroups() {
    const list = this.groupsListTarget
    list.innerHTML = ""

    if (this.groups.length === 0) {
      list.innerHTML = `
        <div class="bg-bg-surface rounded-lg border border-border p-8 text-center">
          <span class="text-3xl">🔗</span>
          <p class="text-sm text-content-muted mt-2">No identity links configured.</p>
        </div>`
      return
    }

    this.groups.forEach((group, i) => {
      const identitiesHtml = group.map(id => {
        const [channel, ...rest] = id.split(":")
        const userId = rest.join(":")
        return `<div class="flex items-center gap-1 bg-bg-base rounded-md px-3 py-1.5 border border-border">
          <span class="text-xs font-mono text-content">${this.escapeHtml(channel)}:</span>
          <span class="text-xs font-mono text-accent">${this.escapeHtml(userId)}</span>
        </div>`
      }).join("")

      const div = document.createElement("div")
      div.className = "bg-bg-surface rounded-lg border border-border p-4"
      div.dataset.groupIndex = i
      div.innerHTML = `
        <div class="flex items-center justify-between mb-3">
          <span class="text-xs font-medium text-content-muted">Group #${i + 1}</span>
          <button type="button" data-action="click->identity-links#removeGroup" data-index="${i}"
                  class="text-xs text-content-muted hover:text-red-400 transition-colors">🗑️ Remove</button>
        </div>
        <div class="flex flex-wrap gap-2">${identitiesHtml}</div>`
      list.appendChild(div)
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.groups.length} group${this.groups.length === 1 ? '' : 's'}`
    }
  }

  updatePreview() {
    if (this.hasJsonPreviewTarget) {
      this.jsonPreviewTarget.textContent = JSON.stringify(this.groups, null, 2)
    }
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

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
