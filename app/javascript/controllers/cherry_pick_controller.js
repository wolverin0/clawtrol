import { Controller } from "@hotwired/stimulus"

/**
 * Cherry-pick pipeline controller.
 * Manages commit selection, preview, dry-run, execute, and verify flow.
 */
export default class extends Controller {
  static targets = ["commitList", "preview", "previewContent", "results", "resultsContent",
                     "selectAll", "executeBtn", "dryRunBtn", "verifyBtn", "statusBadge"]

  connect() {
    this.selectedCommits = new Set()
    this.updateButtons()
  }

  // Toggle individual commit checkbox
  toggleCommit(event) {
    const hash = event.target.dataset.hash
    if (event.target.checked) {
      this.selectedCommits.add(hash)
    } else {
      this.selectedCommits.delete(hash)
    }
    this.updateButtons()
    this.updateSelectAll()
  }

  // Select/deselect all factory commits
  toggleAll(event) {
    const checkboxes = this.commitListTarget.querySelectorAll("input[type=checkbox]")
    checkboxes.forEach(cb => {
      cb.checked = event.target.checked
      if (event.target.checked) {
        this.selectedCommits.add(cb.dataset.hash)
      } else {
        this.selectedCommits.delete(cb.dataset.hash)
      }
    })
    this.updateButtons()
  }

  updateSelectAll() {
    if (!this.hasSelectAllTarget) return
    const checkboxes = this.commitListTarget.querySelectorAll("input[type=checkbox]")
    const allChecked = Array.from(checkboxes).every(cb => cb.checked)
    this.selectAllTarget.checked = allChecked
  }

  updateButtons() {
    const count = this.selectedCommits.size
    if (this.hasExecuteBtnTarget) {
      this.executeBtnTarget.disabled = count === 0
      this.executeBtnTarget.textContent = count > 0
        ? `🍒 Cherry-Pick ${count} Commit${count > 1 ? "s" : ""}`
        : "🍒 Cherry-Pick"
    }
    if (this.hasDryRunBtnTarget) {
      this.dryRunBtnTarget.disabled = count === 0
    }
  }

  // Preview a single commit's diff
  async previewCommit(event) {
    event.preventDefault()
    const hash = event.currentTarget.dataset.hash
    this.previewTarget.classList.remove("hidden")
    this.previewContentTarget.innerHTML = `<div class="text-center py-4 text-gray-400">Loading diff for ${hash.slice(0,7)}...</div>`

    try {
      const response = await fetch("/factory/cherry_pick/preview", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({ commit: hash })
      })
      const data = await response.json()
      if (data.success) {
        this.previewContentTarget.innerHTML = `
          <div class="mb-2 text-sm font-medium text-gray-900 dark:text-white">${this.escapeHtml(data.data.message)}</div>
          <div class="mb-2 text-xs text-gray-500">${data.data.files.length} file(s): ${data.data.files.map(f => this.escapeHtml(f)).join(", ")}</div>
          <pre class="text-xs font-mono leading-relaxed whitespace-pre-wrap text-gray-700 dark:text-gray-300 max-h-[400px] overflow-y-auto bg-gray-50 dark:bg-gray-900 p-3 rounded">${this.escapeHtml(data.data.diff)}</pre>
        `
      } else {
        this.previewContentTarget.innerHTML = `<div class="text-red-500 text-sm">${this.escapeHtml(data.message)}</div>`
      }
    } catch (err) {
      this.previewContentTarget.innerHTML = `<div class="text-red-500 text-sm">Request failed: ${this.escapeHtml(err.message)}</div>`
    }
  }

  // Dry run — check if commits would apply cleanly
  async dryRun() {
    await this.executeInternal(true)
  }

  // Execute real cherry-pick
  async execute() {
    if (!confirm(`Cherry-pick ${this.selectedCommits.size} commit(s) to production ~/clawdeck?\n\nThis modifies the production codebase.`)) return
    await this.executeInternal(false)
  }

  async executeInternal(dryRun) {
    const commits = Array.from(this.selectedCommits)
    this.resultsTarget.classList.remove("hidden")
    this.resultsContentTarget.innerHTML = `<div class="text-center py-4 text-gray-400">${dryRun ? "Dry run" : "Cherry-picking"}...</div>`
    if (this.hasVerifyBtnTarget) this.verifyBtnTarget.classList.add("hidden")

    try {
      const response = await fetch("/factory/cherry_pick/execute", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({ commits, dry_run: dryRun ? "true" : "false" })
      })
      const data = await response.json()
      this.renderResults(data, dryRun)
    } catch (err) {
      this.resultsContentTarget.innerHTML = `<div class="text-red-500 text-sm">Request failed: ${this.escapeHtml(err.message)}</div>`
    }
  }

  renderResults(data, dryRun) {
    const results = data.data?.results || []
    const lines = results.map(r => {
      const icon = r.status === "ok" ? "✅" : "❌"
      return `<div class="flex items-center gap-2 text-sm py-1">
        <span>${icon}</span>
        <code class="text-xs font-mono text-indigo-600 dark:text-indigo-400">${r.hash.slice(0,7)}</code>
        <span class="text-gray-700 dark:text-gray-300">${this.escapeHtml(r.message)}</span>
      </div>`
    }).join("")

    const badge = data.success
      ? `<span class="px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">${dryRun ? "Dry Run OK" : "Applied"}</span>`
      : `<span class="px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">${dryRun ? "Would Conflict" : "Conflict"}</span>`

    this.resultsContentTarget.innerHTML = `
      <div class="mb-2 flex items-center gap-2">
        ${badge}
        <span class="text-sm text-gray-600 dark:text-gray-400">${this.escapeHtml(data.message)}</span>
      </div>
      ${lines}
    `

    // Show verify button only after real (non-dry-run) success
    if (!dryRun && data.success && this.hasVerifyBtnTarget) {
      this.verifyBtnTarget.classList.remove("hidden")
    }
  }

  // Run tests in production
  async verify() {
    if (this.hasVerifyBtnTarget) {
      this.verifyBtnTarget.disabled = true
      this.verifyBtnTarget.textContent = "🧪 Running tests..."
    }

    try {
      const response = await fetch("/factory/cherry_pick/verify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        }
      })
      const data = await response.json()
      const icon = data.success ? "✅" : "❌"
      const color = data.success ? "green" : "red"
      this.resultsContentTarget.innerHTML += `
        <div class="mt-3 p-3 rounded bg-${color}-50 dark:bg-${color}-900/20 border border-${color}-200 dark:border-${color}-800">
          <div class="text-sm font-medium text-${color}-800 dark:text-${color}-200">${icon} ${this.escapeHtml(data.message)}</div>
          <pre class="mt-2 text-xs font-mono text-gray-700 dark:text-gray-300 max-h-[200px] overflow-y-auto">${this.escapeHtml(data.data?.output || "")}</pre>
        </div>
      `
    } catch (err) {
      this.resultsContentTarget.innerHTML += `<div class="mt-2 text-red-500 text-sm">Verify failed: ${this.escapeHtml(err.message)}</div>`
    } finally {
      if (this.hasVerifyBtnTarget) {
        this.verifyBtnTarget.disabled = false
        this.verifyBtnTarget.textContent = "🧪 Verify (Run Tests)"
      }
    }
  }

  closePreview() {
    this.previewTarget.classList.add("hidden")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text || ""
    return div.innerHTML
  }
}
