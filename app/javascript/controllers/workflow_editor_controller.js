import { Controller } from "@hotwired/stimulus"

// Minimal DAG editor MVP.
// Definition format:
// { nodes: [{id,type,label,x,y,props}], edges: [{from,to}] }
export default class extends Controller {
  static values = {
    initialDefinition: String,
    workflowId: String
  }

  static targets = [
    "canvas",
    "svg",
    "definitionInput",
    "selectedSummary",
    "labelInput",
    "typeDisplay",
    "autosaveIndicator"
  ]

  connect() {
    this.nodes = []
    this.edges = []
    this.selectedNodeId = null
    this.connectingFromId = null

    this.dragging = null // { id, startX, startY, originX, originY }

    this.dirty = false
    this.saving = false
    this.lastSavedDefinition = null

    this.loadInitial()
    this.persist() // ensure hidden input matches initial
    this.lastSavedDefinition = this.definitionInputTarget?.value
    this.dirty = false
    if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
    this.render()

    this.boundOnPointerMove = this.onPointerMove.bind(this)
    this.boundOnPointerUp = this.onPointerUp.bind(this)
    window.addEventListener("pointermove", this.boundOnPointerMove)
    window.addEventListener("pointerup", this.boundOnPointerUp)

    this.boundBeforeUnload = this.beforeUnload.bind(this)
    window.addEventListener("beforeunload", this.boundBeforeUnload)

    this.updateAutosaveIndicator()
  }

  disconnect() {
    window.removeEventListener("pointermove", this.boundOnPointerMove)
    window.removeEventListener("pointerup", this.boundOnPointerUp)
    window.removeEventListener("beforeunload", this.boundBeforeUnload)

    if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
  }

  loadInitial() {
    let def = null
    try {
      def = JSON.parse(this.initialDefinitionValue || "{}")
    } catch (_e) {
      def = {}
    }

    this.nodes = Array.isArray(def.nodes) ? def.nodes : []
    this.edges = Array.isArray(def.edges) ? def.edges : []

    // Backfill fields
    this.nodes.forEach((n) => {
      n.props ||= {}
      n.label ||= n.type
      n.x ||= 80
      n.y ||= 80
    })
  }

  // --- Actions (add nodes) ---

  addAgent() { this.addNode("agent") }
  addTool() { this.addNode("tool") }
  addRouter() { this.addNode("router") }
  addTrigger() { this.addNode("trigger") }

  addNode(type) {
    const id = `n_${Math.random().toString(36).slice(2, 10)}`
    const offset = 24 * (this.nodes.length % 10)
    this.nodes.push({
      id,
      type,
      label: type.toUpperCase(),
      x: 80 + offset,
      y: 80 + offset,
      props: {}
    })
    this.selectNode(id)
    this.persist()
    this.render()
    this.setStatus(`Added ${type}`)
  }

  clear() {
    if (!confirm("Clear all nodes and edges?")) return
    this.nodes = []
    this.edges = []
    this.selectedNodeId = null
    this.connectingFromId = null
    this.persist()
    this.render()
    this.syncPropertiesPanel()
    this.setStatus("Cleared")
  }

  deleteSelected() {
    if (!this.selectedNodeId) return
    const id = this.selectedNodeId
    this.nodes = this.nodes.filter((n) => n.id !== id)
    this.edges = this.edges.filter((e) => e.from !== id && e.to !== id)
    this.selectedNodeId = null
    this.connectingFromId = null
    this.persist()
    this.render()
    this.syncPropertiesPanel()
    this.setStatus("Deleted node")
  }

  updateSelectedLabel() {
    if (!this.selectedNodeId) return
    const node = this.nodes.find((n) => n.id === this.selectedNodeId)
    if (!node) return
    node.label = this.labelInputTarget.value
    this.persist()
    this.render()
    this.syncPropertiesPanel(false)
  }

  beforeSubmit(event) {
    // Ensure hidden JSON is updated.
    this.persist()
    // allow submit
  }

  // --- Selection / connecting ---

  selectNode(id) {
    this.selectedNodeId = id
    this.syncPropertiesPanel()
  }

  toggleConnect(fromId, toId) {
    if (!fromId || !toId || fromId === toId) return

    const exists = this.edges.some((e) => e.from === fromId && e.to === toId)
    if (exists) {
      this.edges = this.edges.filter((e) => !(e.from === fromId && e.to === toId))
      this.setStatus("Removed edge")
    } else {
      this.edges.push({ from: fromId, to: toId })
      this.setStatus("Added edge")
    }

    this.persist()
    this.render()
  }

  // --- Dragging ---

  onNodePointerDown(event) {
    const id = event.currentTarget.dataset.nodeId
    const node = this.nodes.find((n) => n.id === id)
    if (!node) return

    // Left click selects; second click creates edge when in connect mode.
    if (this.connectingFromId && this.connectingFromId !== id) {
      this.toggleConnect(this.connectingFromId, id)
      this.connectingFromId = null
      this.render()
      return
    }

    this.selectNode(id)

    // Start drag
    this.dragging = {
      id,
      startX: event.clientX,
      startY: event.clientY,
      originX: node.x,
      originY: node.y
    }

    event.preventDefault()
  }

  onNodeClick(event) {
    // Shift+click enters connect mode from this node.
    const id = event.currentTarget.dataset.nodeId
    if (event.shiftKey) {
      this.connectingFromId = id
      this.setStatus("Connect mode: click another node to toggle edge")
      this.render()
      event.preventDefault()
      return
    }
  }

  onPointerMove(event) {
    if (!this.dragging) return
    const node = this.nodes.find((n) => n.id === this.dragging.id)
    if (!node) return

    const dx = event.clientX - this.dragging.startX
    const dy = event.clientY - this.dragging.startY

    node.x = Math.round(this.dragging.originX + dx)
    node.y = Math.round(this.dragging.originY + dy)

    this.persist()
    this.renderEdges() // cheaper than full render
  }

  onPointerUp(_event) {
    if (!this.dragging) return
    this.dragging = null
    this.persist()
    this.render()
  }

  // --- Rendering ---

  render() {
    if (!this.hasCanvasTarget || !this.hasSvgTarget) return

    // Render nodes
    this.canvasTarget.innerHTML = ""
    this.nodes.forEach((node) => {
      const el = document.createElement("div")
      el.dataset.nodeId = node.id
      el.className = this.nodeClass(node)
      el.style.position = "absolute"
      el.style.left = `${node.x}px`
      el.style.top = `${node.y}px`
      el.style.width = "160px"
      el.style.cursor = "grab"
      el.style.userSelect = "none"
      el.style.touchAction = "none"

      el.addEventListener("pointerdown", this.onNodePointerDown.bind(this))
      el.addEventListener("click", this.onNodeClick.bind(this))

      el.innerHTML = `
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <div class="text-[10px] uppercase tracking-wide text-content-muted">${this.escapeHtml(node.type)}</div>
            <div class="text-sm font-semibold text-content truncate">${this.escapeHtml(node.label || node.type)}</div>
          </div>
          <div class="text-[10px] text-content-muted font-mono">${this.escapeHtml(node.id)}</div>
        </div>
        <div class="mt-2 text-[11px] text-content-muted">
          <span class="font-mono">Shift+click</span> to connect
        </div>
      `

      this.canvasTarget.appendChild(el)
    })

    this.renderEdges()
    this.syncPropertiesPanel(false)
  }

  renderEdges() {
    // Clear + rebuild SVG lines
    this.svgTarget.innerHTML = ""

    const svgNS = "http://www.w3.org/2000/svg"

    // marker arrow
    const defs = document.createElementNS(svgNS, "defs")
    const marker = document.createElementNS(svgNS, "marker")
    marker.setAttribute("id", "arrow")
    marker.setAttribute("viewBox", "0 0 10 10")
    marker.setAttribute("refX", "10")
    marker.setAttribute("refY", "5")
    marker.setAttribute("markerWidth", "6")
    marker.setAttribute("markerHeight", "6")
    marker.setAttribute("orient", "auto-start-reverse")

    const path = document.createElementNS(svgNS, "path")
    path.setAttribute("d", "M 0 0 L 10 5 L 0 10 z")
    path.setAttribute("fill", "rgba(148,163,184,0.9)")
    marker.appendChild(path)
    defs.appendChild(marker)
    this.svgTarget.appendChild(defs)

    this.edges.forEach((edge) => {
      const from = this.nodes.find((n) => n.id === edge.from)
      const to = this.nodes.find((n) => n.id === edge.to)
      if (!from || !to) return

      const line = document.createElementNS(svgNS, "line")

      const x1 = from.x + 160
      const y1 = from.y + 28
      const x2 = to.x
      const y2 = to.y + 28

      line.setAttribute("x1", x1)
      line.setAttribute("y1", y1)
      line.setAttribute("x2", x2)
      line.setAttribute("y2", y2)
      line.setAttribute("stroke", "rgba(148,163,184,0.85)")
      line.setAttribute("stroke-width", "2")
      line.setAttribute("marker-end", "url(#arrow)")

      this.svgTarget.appendChild(line)
    })
  }

  nodeClass(node) {
    const selected = node.id === this.selectedNodeId
    const connecting = node.id === this.connectingFromId

    let accent = "border-border"
    if (node.type === "agent") accent = "border-purple-500/40"
    if (node.type === "tool") accent = "border-cyan-500/40"
    if (node.type === "router") accent = "border-amber-500/40"
    if (node.type === "trigger") accent = "border-green-500/40"

    return [
      "bg-bg-elevated",
      "border",
      accent,
      "rounded-lg",
      "p-3",
      "shadow-sm",
      selected ? "ring-2 ring-accent/50" : "",
      connecting ? "ring-2 ring-blue-500/50" : ""
    ].join(" ")
  }

  // --- Persistence ---

  persist() {
    if (!this.hasDefinitionInputTarget) return

    const def = {
      nodes: this.nodes.map((n) => ({
        id: n.id,
        type: n.type,
        label: n.label,
        x: n.x,
        y: n.y,
        props: n.props || {}
      })),
      edges: this.edges.map((e) => ({ from: e.from, to: e.to }))
    }

    this.definitionInputTarget.value = JSON.stringify(def)
    this.markDirty()
    this.scheduleAutosave()
  }

  markDirty() {
    // New workflows (not persisted) can't autosave yet.
    const current = this.definitionInputTarget?.value
    if (current && this.lastSavedDefinition && current === this.lastSavedDefinition) {
      this.dirty = false
    } else {
      this.dirty = true
    }
    this.updateAutosaveIndicator()
  }

  beforeUnload(event) {
    if (!this.dirty) return
    // Modern browsers ignore custom messages but require returnValue set.
    event.preventDefault()
    event.returnValue = "You have unsaved workflow changes."
  }

  scheduleAutosave() {
    if (!this.workflowIdValue) return

    if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
    this.autosaveTimer = window.setTimeout(() => {
      this.autosave().catch(() => {})
    }, 800)
  }

  async autosave() {
    if (!this.workflowIdValue) return
    if (!this.dirty) return
    if (this.saving) return

    this.saving = true
    this.updateAutosaveIndicator()

    const tokenEl = document.querySelector("meta[name='csrf-token']")
    const csrfToken = tokenEl ? tokenEl.getAttribute("content") : null

    const res = await fetch(`/workflows/${this.workflowIdValue}.json`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
      },
      body: JSON.stringify({
        workflow: {
          definition: this.definitionInputTarget.value
        }
      })
    })

    const payload = await res.json().catch(() => ({}))

    this.saving = false

    if (!res.ok || payload.ok === false) {
      this.updateAutosaveIndicator({ error: true })
      return
    }

    this.lastSavedDefinition = this.definitionInputTarget.value
    this.dirty = false
    this.updateAutosaveIndicator()
  }

  updateAutosaveIndicator(opts = {}) {
    if (!this.hasAutosaveIndicatorTarget) return

    if (!this.workflowIdValue) {
      this.autosaveIndicatorTarget.textContent = "(save to enable autosave)"
      return
    }

    if (opts.error) {
      this.autosaveIndicatorTarget.textContent = "Autosave failed"
      return
    }

    if (this.saving) {
      this.autosaveIndicatorTarget.textContent = "Saving…"
      return
    }

    this.autosaveIndicatorTarget.textContent = this.dirty ? "Unsaved changes" : "Saved"
  }

  // --- UI helpers ---

  syncPropertiesPanel(updateInputs = true) {
    if (!this.hasSelectedSummaryTarget) return

    const node = this.nodes.find((n) => n.id === this.selectedNodeId)
    if (!node) {
      this.selectedSummaryTarget.textContent = "None"
      this.typeDisplayTarget.textContent = "—"
      if (updateInputs && this.hasLabelInputTarget) this.labelInputTarget.value = ""
      return
    }

    this.selectedSummaryTarget.textContent = `${node.label} (${node.id})`
    this.typeDisplayTarget.textContent = node.type
    if (updateInputs && this.hasLabelInputTarget) this.labelInputTarget.value = node.label || ""
  }

  setStatus(text) {
    const el = this.element.querySelector("[data-workflow-editor-status]")
    if (!el) return
    el.textContent = text
    window.clearTimeout(this.statusTimer)
    this.statusTimer = window.setTimeout(() => { el.textContent = "" }, 2000)
  }

  escapeHtml(str) {
    return String(str || "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
