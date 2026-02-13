import { Controller } from "@hotwired/stimulus"

// Enhanced DAG workflow editor with rich node types, curved edges, and execution visualization.
// Definition format: { nodes: [{id,type,label,x,y,props,status}], edges: [{from,to}] }

const NODE_TYPES = {
  agent:        { icon: "\u{1F916}", color: "purple", borderClass: "border-purple-500/60", bgClass: "bg-purple-500/10",  badgeClass: "bg-purple-500/20 text-purple-300" },
  tool:         { icon: "\u{1F527}", color: "cyan",   borderClass: "border-cyan-500/60",   bgClass: "bg-cyan-500/10",    badgeClass: "bg-cyan-500/20 text-cyan-300" },
  router:       { icon: "\u{1F500}", color: "amber",  borderClass: "border-amber-500/60",  bgClass: "bg-amber-500/10",   badgeClass: "bg-amber-500/20 text-amber-300" },
  trigger:      { icon: "\u26A1",    color: "green",  borderClass: "border-green-500/60",  bgClass: "bg-green-500/10",   badgeClass: "bg-green-500/20 text-green-300" },
  nightshift:   { icon: "\u{1F319}", color: "indigo", borderClass: "border-indigo-500/60", bgClass: "bg-indigo-500/10",  badgeClass: "bg-indigo-500/20 text-indigo-300" },
  conditional:  { icon: "\u{1F536}", color: "orange", borderClass: "border-orange-500/60", bgClass: "bg-orange-500/10",  badgeClass: "bg-orange-500/20 text-orange-300" },
  notification: { icon: "\u{1F4E2}", color: "pink",   borderClass: "border-pink-500/60",   bgClass: "bg-pink-500/10",    badgeClass: "bg-pink-500/20 text-pink-300" },
  delay:        { icon: "\u23F1\uFE0F",  color: "slate",  borderClass: "border-slate-400/60",  bgClass: "bg-slate-500/10",   badgeClass: "bg-slate-500/20 text-slate-300" }
}

const STATUS_COLORS = {
  idle:      { dot: "bg-gray-500",   ring: "" },
  pending:   { dot: "bg-yellow-400", ring: "ring-yellow-400/30" },
  running:   { dot: "bg-blue-400 animate-pulse", ring: "ring-2 ring-blue-400/40" },
  completed: { dot: "bg-emerald-400", ring: "ring-emerald-400/20" },
  ok:        { dot: "bg-emerald-400", ring: "ring-emerald-400/20" },
  failed:    { dot: "bg-red-400",    ring: "ring-red-400/20" },
  error:     { dot: "bg-red-400",    ring: "ring-red-400/20" },
  skipped:   { dot: "bg-gray-400",   ring: "" }
}

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
    "autosaveIndicator",
    "propsContainer",
    "executionLog",
    "runBtn"
  ]

  connect() {
    this.nodes = []
    this.edges = []
    this.selectedNodeId = null
    this.connectingFromId = null
    this.dragging = null
    this.dirty = false
    this.saving = false
    this.lastSavedDefinition = null
    this.nodeStatuses = {} // id -> status string
    this.executionLogs = []

    this.loadInitial()
    this.persist()
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
    this.subscribeToExecution()
  }

  disconnect() {
    window.removeEventListener("pointermove", this.boundOnPointerMove)
    window.removeEventListener("pointerup", this.boundOnPointerUp)
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
    if (this.autosaveTimer) window.clearTimeout(this.autosaveTimer)
    if (this.executionSubscription) this.executionSubscription.unsubscribe()
  }

  loadInitial() {
    let def = null
    try { def = JSON.parse(this.initialDefinitionValue || "{}") } catch (_e) { def = {} }
    this.nodes = Array.isArray(def.nodes) ? def.nodes : []
    this.edges = Array.isArray(def.edges) ? def.edges : []
    this.nodes.forEach((n) => {
      n.props ||= {}
      n.label ||= n.type
      n.x ||= 80
      n.y ||= 80
    })
  }

  // --- Node type actions ---
  addAgent() { this.addNode("agent") }
  addTool() { this.addNode("tool") }
  addRouter() { this.addNode("router") }
  addTrigger() { this.addNode("trigger") }
  addNightshift() { this.addNode("nightshift") }
  addConditional() { this.addNode("conditional") }
  addNotification() { this.addNode("notification") }
  addDelay() { this.addNode("delay") }

  addNode(type) {
    const id = `n_${Math.random().toString(36).slice(2, 10)}`
    const offset = 30 * (this.nodes.length % 8)
    const typeMeta = NODE_TYPES[type] || NODE_TYPES.trigger
    this.nodes.push({
      id, type,
      label: typeMeta.icon + " " + type.charAt(0).toUpperCase() + type.slice(1),
      x: 100 + offset,
      y: 100 + offset,
      props: {}
    })
    this.selectNode(id)
    this.persist()
    this.render()
    this.setStatus(`Added ${type} node`)
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

  beforeSubmit(_event) { this.persist() }

  // --- Selection / connecting ---
  selectNode(id) {
    this.selectedNodeId = id
    this.syncPropertiesPanel()
    this.render()
  }

  toggleConnect(fromId, toId) {
    if (!fromId || !toId || fromId === toId) return
    const exists = this.edges.some((e) => e.from === fromId && e.to === toId)
    if (exists) {
      this.edges = this.edges.filter((e) => !(e.from === fromId && e.to === toId))
      this.setStatus("Removed edge")
    } else {
      this.edges.push({ from: fromId, to: toId })
      this.setStatus("Connected nodes")
    }
    this.persist()
    this.render()
  }

  // --- Dragging ---
  onNodePointerDown(event) {
    const id = event.currentTarget.dataset.nodeId
    const node = this.nodes.find((n) => n.id === id)
    if (!node) return

    if (this.connectingFromId && this.connectingFromId !== id) {
      this.toggleConnect(this.connectingFromId, id)
      this.connectingFromId = null
      this.render()
      return
    }

    this.selectNode(id)
    this.dragging = {
      id, startX: event.clientX, startY: event.clientY,
      originX: node.x, originY: node.y
    }
    event.preventDefault()
  }

  onNodeClick(event) {
    const id = event.currentTarget.dataset.nodeId
    if (event.shiftKey) {
      this.connectingFromId = id
      this.setStatus("Connect mode: click target node")
      this.render()
      event.preventDefault()
    }
  }

  onPointerMove(event) {
    if (!this.dragging) return
    const node = this.nodes.find((n) => n.id === this.dragging.id)
    if (!node) return
    node.x = Math.max(0, Math.round(this.dragging.originX + (event.clientX - this.dragging.startX)))
    node.y = Math.max(0, Math.round(this.dragging.originY + (event.clientY - this.dragging.startY)))
    this.persist()
    this.renderPositions()
    this.renderEdges()
  }

  onPointerUp(_event) {
    if (!this.dragging) return
    this.dragging = null
    this.persist()
  }

  // --- Auto-layout ---
  autoLayout() {
    if (this.nodes.length === 0) return

    // Build adjacency from edges
    const incoming = {}
    const outgoing = {}
    this.nodes.forEach((n) => { incoming[n.id] = []; outgoing[n.id] = [] })
    this.edges.forEach((e) => {
      if (outgoing[e.from]) outgoing[e.from].push(e.to)
      if (incoming[e.to]) incoming[e.to].push(e.from)
    })

    // Topological layers (Kahn's algorithm)
    const inDegree = {}
    this.nodes.forEach((n) => { inDegree[n.id] = (incoming[n.id] || []).length })
    const queue = this.nodes.filter((n) => inDegree[n.id] === 0).map((n) => n.id)
    const layers = []

    while (queue.length > 0) {
      const layer = [...queue]
      layers.push(layer)
      queue.length = 0
      layer.forEach((id) => {
        ;(outgoing[id] || []).forEach((toId) => {
          inDegree[toId]--
          if (inDegree[toId] === 0) queue.push(toId)
        })
      })
    }

    // Position orphan nodes (not in any layer) at the end
    const placed = new Set(layers.flat())
    const orphans = this.nodes.filter((n) => !placed.has(n.id)).map((n) => n.id)
    if (orphans.length) layers.push(orphans)

    // Layout: horizontal layers, 220px apart; nodes within layer spaced 100px vertically
    const xStart = 60
    const yStart = 60
    const layerGap = 260
    const nodeGap = 110

    layers.forEach((layer, li) => {
      const totalHeight = layer.length * nodeGap
      const startY = yStart + Math.max(0, (400 - totalHeight) / 2)
      layer.forEach((id, ni) => {
        const node = this.nodes.find((n) => n.id === id)
        if (node) {
          node.x = xStart + li * layerGap
          node.y = startY + ni * nodeGap
        }
      })
    })

    this.persist()
    this.render()
    this.setStatus("Auto-layout applied")
  }

  // --- Import Nightshift Missions ---
  async importNightshift() {
    this.setStatus("Fetching missions...")
    try {
      const tokenEl = document.querySelector("meta[name='csrf-token']")
      const csrfToken = tokenEl ? tokenEl.getAttribute("content") : null
      const apiTokenEl = document.querySelector("meta[name='api-token']")
      const apiToken = apiTokenEl ? apiTokenEl.getAttribute("content") : null

      const headers = { "Accept": "application/json" }
      if (apiToken) headers["Authorization"] = `Bearer ${apiToken}`
      if (csrfToken) headers["X-CSRF-Token"] = csrfToken

      const res = await fetch("/api/v1/nightshift/missions", { headers })
      if (!res.ok) {
        this.setStatus("Failed to fetch missions")
        return
      }
      const missions = await res.json()
      if (!Array.isArray(missions) || missions.length === 0) {
        this.setStatus("No missions found")
        return
      }

      // Add trigger node + mission nodes in a pipeline
      const triggerId = `n_${Math.random().toString(36).slice(2, 10)}`
      this.nodes.push({
        id: triggerId, type: "trigger",
        label: "\u26A1 Nightshift Start",
        x: 60, y: 200, props: {}
      })

      let prevId = triggerId
      missions.forEach((m, i) => {
        const id = `n_${Math.random().toString(36).slice(2, 10)}`
        this.nodes.push({
          id, type: "nightshift",
          label: `\u{1F319} ${m.name || m.title}`,
          x: 320 + i * 260,
          y: 120 + (i % 3) * 110,
          props: {
            mission_id: m.id,
            mission_name: m.name || m.title,
            estimated_minutes: m.estimated_minutes,
            model: m.model
          }
        })
        this.edges.push({ from: prevId, to: id })
        prevId = id
      })

      // Add notification at end
      const notifId = `n_${Math.random().toString(36).slice(2, 10)}`
      this.nodes.push({
        id: notifId, type: "notification",
        label: "\u{1F4E2} Complete",
        x: 320 + missions.length * 260,
        y: 200,
        props: { channel: "telegram", message: "Nightshift complete: {{completed}}/{{total}} missions" }
      })
      this.edges.push({ from: prevId, to: notifId })

      this.persist()
      this.autoLayout()
      this.setStatus(`Imported ${missions.length} missions`)
    } catch (e) {
      this.setStatus("Import failed: " + e.message)
    }
  }

  // --- Run workflow ---
  async runWorkflow() {
    if (!this.workflowIdValue) {
      this.setStatus("Save workflow first")
      return
    }

    if (this.hasRunBtnTarget) {
      this.runBtnTarget.disabled = true
      this.runBtnTarget.textContent = "Running..."
    }

    // Reset statuses
    this.nodeStatuses = {}
    this.nodes.forEach((n) => { this.nodeStatuses[n.id] = "pending" })
    this.executionLogs = [{ time: new Date().toLocaleTimeString(), text: "Starting workflow execution..." }]
    this.render()
    this.renderExecutionLog()

    try {
      const tokenEl = document.querySelector("meta[name='csrf-token']")
      const csrfToken = tokenEl ? tokenEl.getAttribute("content") : null
      const apiTokenEl = document.querySelector("meta[name='api-token']")
      const apiToken = apiTokenEl ? apiTokenEl.getAttribute("content") : null

      const headers = { "Content-Type": "application/json", "Accept": "application/json" }
      if (apiToken) headers["Authorization"] = `Bearer ${apiToken}`
      if (csrfToken) headers["X-CSRF-Token"] = csrfToken

      const res = await fetch(`/api/v1/workflows/${this.workflowIdValue}/run`, {
        method: "POST", headers
      })
      const result = await res.json()

      // Update node statuses from result
      if (result.nodes) {
        result.nodes.forEach((nr) => {
          this.nodeStatuses[nr.id] = nr.status || "completed"
          this.executionLogs.push({
            time: new Date().toLocaleTimeString(),
            text: `${nr.label}: ${nr.status} ${nr.logs ? "- " + nr.logs.join("; ") : ""}`
          })
        })
      }

      this.executionLogs.push({
        time: new Date().toLocaleTimeString(),
        text: `Workflow ${result.status === "ok" ? "completed successfully" : "finished with status: " + result.status}`
      })

      if (result.errors && result.errors.length > 0) {
        result.errors.forEach((e) => {
          this.executionLogs.push({ time: new Date().toLocaleTimeString(), text: `ERROR: ${e}` })
        })
      }
    } catch (e) {
      this.executionLogs.push({ time: new Date().toLocaleTimeString(), text: `Execution failed: ${e.message}` })
    }

    if (this.hasRunBtnTarget) {
      this.runBtnTarget.disabled = false
      this.runBtnTarget.textContent = "\u25B6 Run"
    }

    this.render()
    this.renderExecutionLog()
  }

  // --- ActionCable subscription for real-time updates ---
  subscribeToExecution() {
    if (!this.workflowIdValue) return
    try {
      if (typeof window.Stimulus === "undefined" && typeof window.ActionCable === "undefined") return

      // Will be enhanced when WorkflowExecutionChannel is available
      // For now, execution updates come from the run response
    } catch (_e) {
      // ActionCable not available
    }
  }

  // --- Rendering ---
  render() {
    if (!this.hasCanvasTarget || !this.hasSvgTarget) return
    this.canvasTarget.innerHTML = ""

    this.nodes.forEach((node) => {
      const typeMeta = NODE_TYPES[node.type] || NODE_TYPES.trigger
      const status = this.nodeStatuses[node.id] || "idle"
      const statusMeta = STATUS_COLORS[status] || STATUS_COLORS.idle
      const selected = node.id === this.selectedNodeId
      const connecting = node.id === this.connectingFromId

      const el = document.createElement("div")
      el.dataset.nodeId = node.id
      el.style.position = "absolute"
      el.style.left = `${node.x}px`
      el.style.top = `${node.y}px`
      el.style.width = "200px"
      el.style.cursor = "grab"
      el.style.userSelect = "none"
      el.style.touchAction = "none"
      el.style.zIndex = selected ? "20" : "10"

      el.className = [
        "rounded-xl border-2 p-3 shadow-lg backdrop-blur-sm transition-shadow",
        typeMeta.borderClass,
        typeMeta.bgClass,
        "bg-bg-elevated/90",
        selected ? "ring-2 ring-accent shadow-xl scale-[1.02]" : "hover:shadow-md",
        connecting ? "ring-2 ring-blue-400 shadow-blue-500/20" : "",
        statusMeta.ring
      ].filter(Boolean).join(" ")

      el.addEventListener("pointerdown", this.onNodePointerDown.bind(this))
      el.addEventListener("click", this.onNodeClick.bind(this))

      // Props summary
      let propsHint = ""
      if (node.type === "agent" && node.props?.model) propsHint = node.props.model
      if (node.type === "nightshift" && node.props?.mission_name) propsHint = node.props.mission_name
      if (node.type === "conditional" && node.props?.expression) propsHint = node.props.expression.substring(0, 20)
      if (node.type === "delay" && node.props?.duration) propsHint = node.props.duration + "s"
      if (node.type === "notification" && node.props?.channel) propsHint = node.props.channel

      el.innerHTML = `
        <div class="flex items-start gap-2.5">
          <div class="text-xl flex-shrink-0 mt-0.5">${typeMeta.icon}</div>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-1.5">
              <span class="inline-block px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider rounded ${typeMeta.badgeClass}">${this.escapeHtml(node.type)}</span>
              <span class="w-2 h-2 rounded-full flex-shrink-0 ${statusMeta.dot}"></span>
            </div>
            <div class="text-sm font-semibold text-content mt-1 truncate">${this.escapeHtml(node.label)}</div>
            ${propsHint ? `<div class="text-[10px] text-content-muted mt-0.5 truncate">${this.escapeHtml(propsHint)}</div>` : ""}
          </div>
        </div>
        <div class="mt-2 flex items-center justify-between">
          <span class="text-[9px] text-content-muted/60 font-mono">${this.escapeHtml(node.id)}</span>
          <span class="text-[9px] text-content-muted">shift+click to wire</span>
        </div>
      `

      this.canvasTarget.appendChild(el)
    })

    this.renderEdges()
    this.syncPropertiesPanel(false)
  }

  renderPositions() {
    if (!this.hasCanvasTarget) return
    const nodeEls = this.canvasTarget.querySelectorAll("[data-node-id]")
    nodeEls.forEach((el) => {
      const node = this.nodes.find((n) => n.id === el.dataset.nodeId)
      if (node) {
        el.style.left = `${node.x}px`
        el.style.top = `${node.y}px`
      }
    })
  }

  renderEdges() {
    if (!this.hasSvgTarget) return
    this.svgTarget.innerHTML = ""
    const svgNS = "http://www.w3.org/2000/svg"

    // Defs: arrow markers
    const defs = document.createElementNS(svgNS, "defs")

    const marker = document.createElementNS(svgNS, "marker")
    marker.setAttribute("id", "arrow")
    marker.setAttribute("viewBox", "0 0 10 10")
    marker.setAttribute("refX", "10")
    marker.setAttribute("refY", "5")
    marker.setAttribute("markerWidth", "6")
    marker.setAttribute("markerHeight", "6")
    marker.setAttribute("orient", "auto-start-reverse")
    const arrowPath = document.createElementNS(svgNS, "path")
    arrowPath.setAttribute("d", "M 0 0 L 10 5 L 0 10 z")
    arrowPath.setAttribute("fill", "rgba(148,163,184,0.9)")
    marker.appendChild(arrowPath)
    defs.appendChild(marker)

    // Glow marker for running edges
    const markerGlow = marker.cloneNode(true)
    markerGlow.setAttribute("id", "arrow-glow")
    markerGlow.querySelector("path").setAttribute("fill", "rgba(96,165,250,0.9)")
    defs.appendChild(markerGlow)

    this.svgTarget.appendChild(defs)

    // Render curved bezier edges
    this.edges.forEach((edge) => {
      const from = this.nodes.find((n) => n.id === edge.from)
      const to = this.nodes.find((n) => n.id === edge.to)
      if (!from || !to) return

      const nodeW = 200
      const nodeH = 80

      // Exit from right center, enter from left center
      const x1 = from.x + nodeW
      const y1 = from.y + nodeH / 2
      const x2 = to.x
      const y2 = to.y + nodeH / 2

      // Control points for smooth cubic bezier
      const dx = Math.abs(x2 - x1) * 0.5
      const cp1x = x1 + dx
      const cp1y = y1
      const cp2x = x2 - dx
      const cp2y = y2

      const fromStatus = this.nodeStatuses[edge.from] || "idle"
      const isActive = fromStatus === "running" || fromStatus === "completed" || fromStatus === "ok"

      const path = document.createElementNS(svgNS, "path")
      path.setAttribute("d", `M ${x1} ${y1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${x2} ${y2}`)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", isActive ? "rgba(96,165,250,0.8)" : "rgba(148,163,184,0.5)")
      path.setAttribute("stroke-width", isActive ? "2.5" : "2")
      path.setAttribute("marker-end", isActive ? "url(#arrow-glow)" : "url(#arrow)")

      if (fromStatus === "running") {
        path.setAttribute("stroke-dasharray", "8 4")
        const animate = document.createElementNS(svgNS, "animate")
        animate.setAttribute("attributeName", "stroke-dashoffset")
        animate.setAttribute("from", "24")
        animate.setAttribute("to", "0")
        animate.setAttribute("dur", "0.8s")
        animate.setAttribute("repeatCount", "indefinite")
        path.appendChild(animate)
      }

      this.svgTarget.appendChild(path)
    })
  }

  nodeClass(_node) { /* unused, inline in render */ }

  // --- Properties Panel ---
  syncPropertiesPanel(updateInputs = true) {
    if (!this.hasSelectedSummaryTarget) return
    const node = this.nodes.find((n) => n.id === this.selectedNodeId)

    if (!node) {
      this.selectedSummaryTarget.textContent = "None"
      this.typeDisplayTarget.textContent = "\u2014"
      if (updateInputs && this.hasLabelInputTarget) this.labelInputTarget.value = ""
      if (this.hasPropsContainerTarget) this.propsContainerTarget.innerHTML = '<p class="text-[11px] text-content-muted">Select a node to configure</p>'
      return
    }

    const typeMeta = NODE_TYPES[node.type] || NODE_TYPES.trigger
    this.selectedSummaryTarget.innerHTML = `${typeMeta.icon} ${this.escapeHtml(node.label)}`
    this.typeDisplayTarget.innerHTML = `<span class="inline-block px-1.5 py-0.5 text-[9px] font-bold uppercase rounded ${typeMeta.badgeClass}">${this.escapeHtml(node.type)}</span>`
    if (updateInputs && this.hasLabelInputTarget) this.labelInputTarget.value = node.label || ""

    if (this.hasPropsContainerTarget) {
      this.propsContainerTarget.innerHTML = this.buildPropsEditor(node)
      this.bindPropsInputs(node)
    }
  }

  buildPropsEditor(node) {
    const inputClass = "mt-1 w-full px-2.5 py-1.5 text-xs bg-bg-surface border border-border rounded-md text-content focus:outline-none focus:ring-1 focus:ring-accent/50"
    const labelClass = "block text-[10px] font-medium text-content-muted uppercase tracking-wide"
    const textareaClass = inputClass + " resize-y"

    switch (node.type) {
      case "agent":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Model</label>
              <select data-prop="model" class="${inputClass}">
                <option value="opus" ${node.props?.model === "opus" ? "selected" : ""}>Opus</option>
                <option value="sonnet" ${node.props?.model === "sonnet" ? "selected" : ""}>Sonnet</option>
                <option value="haiku" ${node.props?.model === "haiku" ? "selected" : ""}>Haiku</option>
              </select>
            </div>
            <div><label class="${labelClass}">Prompt</label>
              <textarea data-prop="prompt" rows="4" class="${textareaClass}" placeholder="Agent instructions...">${this.escapeHtml(node.props?.prompt || "")}</textarea>
            </div>
            <div><label class="${labelClass}">Persona</label>
              <input data-prop="persona" type="text" class="${inputClass}" placeholder="e.g. Otacon" value="${this.escapeHtml(node.props?.persona || "")}" />
            </div>
          </div>`

      case "nightshift":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Mission Name</label>
              <input data-prop="mission_name" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.mission_name || "")}" placeholder="e.g. CVE Monitor" />
            </div>
            <div><label class="${labelClass}">Mission ID</label>
              <input data-prop="mission_id" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.mission_id || "")}" readonly />
            </div>
            <div><label class="${labelClass}">Est. Minutes</label>
              <input data-prop="estimated_minutes" type="number" class="${inputClass}" value="${node.props?.estimated_minutes || ""}" />
            </div>
            <div><label class="${labelClass}">Model Override</label>
              <select data-prop="model" class="${inputClass}">
                <option value="" ${!node.props?.model ? "selected" : ""}>Default</option>
                <option value="opus" ${node.props?.model === "opus" ? "selected" : ""}>Opus</option>
                <option value="sonnet" ${node.props?.model === "sonnet" ? "selected" : ""}>Sonnet</option>
                <option value="haiku" ${node.props?.model === "haiku" ? "selected" : ""}>Haiku</option>
              </select>
            </div>
          </div>`

      case "conditional":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Condition Expression</label>
              <textarea data-prop="expression" rows="2" class="${textareaClass}" placeholder="e.g. status == 'ok'">${this.escapeHtml(node.props?.expression || "")}</textarea>
            </div>
            <div><label class="${labelClass}">True Label</label>
              <input data-prop="true_label" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.true_label || "Yes")}" />
            </div>
            <div><label class="${labelClass}">False Label</label>
              <input data-prop="false_label" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.false_label || "No")}" />
            </div>
          </div>`

      case "notification":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Channel</label>
              <select data-prop="channel" class="${inputClass}">
                <option value="telegram" ${node.props?.channel === "telegram" ? "selected" : ""}>Telegram</option>
                <option value="webhook" ${node.props?.channel === "webhook" ? "selected" : ""}>Webhook</option>
              </select>
            </div>
            <div><label class="${labelClass}">Message</label>
              <textarea data-prop="message" rows="3" class="${textareaClass}" placeholder="Notification message...">${this.escapeHtml(node.props?.message || "")}</textarea>
            </div>
          </div>`

      case "delay":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Duration (seconds)</label>
              <input data-prop="duration" type="number" class="${inputClass}" value="${node.props?.duration || 60}" min="1" />
            </div>
          </div>`

      case "router":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Routing Expression</label>
              <textarea data-prop="expression" rows="3" class="${textareaClass}" placeholder="Route condition...">${this.escapeHtml(node.props?.expression || "")}</textarea>
            </div>
          </div>`

      case "tool":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Tool Name</label>
              <input data-prop="tool" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.tool || "")}" placeholder="e.g. web_search" />
            </div>
            <div><label class="${labelClass}">Arguments</label>
              <textarea data-prop="args" rows="2" class="${textareaClass}" placeholder='{"key": "value"}'>${this.escapeHtml(node.props?.args || "")}</textarea>
            </div>
          </div>`

      case "trigger":
        return `
          <div class="space-y-2">
            <div><label class="${labelClass}">Trigger Type</label>
              <select data-prop="trigger_type" class="${inputClass}">
                <option value="manual" ${node.props?.trigger_type === "manual" ? "selected" : ""}>Manual</option>
                <option value="schedule" ${node.props?.trigger_type === "schedule" ? "selected" : ""}>Schedule</option>
                <option value="webhook" ${node.props?.trigger_type === "webhook" ? "selected" : ""}>Webhook</option>
              </select>
            </div>
            <div><label class="${labelClass}">Schedule / URL</label>
              <input data-prop="schedule" type="text" class="${inputClass}" value="${this.escapeHtml(node.props?.schedule || "")}" placeholder="e.g. at 11pm every day" />
            </div>
          </div>`

      default:
        return '<p class="text-[11px] text-content-muted">No properties for this type</p>'
    }
  }

  bindPropsInputs(node) {
    if (!this.hasPropsContainerTarget) return
    const inputs = this.propsContainerTarget.querySelectorAll("[data-prop]")
    inputs.forEach((input) => {
      const propName = input.dataset.prop
      input.addEventListener("input", () => {
        node.props[propName] = input.value
        this.persist()
        this.render()
      })
      input.addEventListener("change", () => {
        node.props[propName] = input.value
        this.persist()
        this.render()
      })
    })
  }

  // --- Execution Log ---
  renderExecutionLog() {
    if (!this.hasExecutionLogTarget) return
    if (this.executionLogs.length === 0) {
      this.executionLogTarget.innerHTML = '<p class="text-[10px] text-content-muted italic">No execution history</p>'
      return
    }
    this.executionLogTarget.innerHTML = this.executionLogs.map((log) =>
      `<div class="flex gap-2 text-[10px] font-mono">
        <span class="text-content-muted flex-shrink-0">${this.escapeHtml(log.time)}</span>
        <span class="text-content">${this.escapeHtml(log.text)}</span>
      </div>`
    ).join("")
    this.executionLogTarget.scrollTop = this.executionLogTarget.scrollHeight
  }

  // --- Persistence ---
  persist() {
    if (!this.hasDefinitionInputTarget) return
    const def = {
      nodes: this.nodes.map((n) => ({
        id: n.id, type: n.type, label: n.label,
        x: n.x, y: n.y, props: n.props || {}
      })),
      edges: this.edges.map((e) => ({ from: e.from, to: e.to }))
    }
    this.definitionInputTarget.value = JSON.stringify(def)
    this.markDirty()
    this.scheduleAutosave()
  }

  markDirty() {
    const current = this.definitionInputTarget?.value
    this.dirty = !(current && this.lastSavedDefinition && current === this.lastSavedDefinition)
    this.updateAutosaveIndicator()
  }

  beforeUnload(event) {
    if (!this.dirty) return
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
    if (!this.workflowIdValue || !this.dirty || this.saving) return
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
      body: JSON.stringify({ workflow: { definition: this.definitionInputTarget.value } })
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
    if (opts.error) { this.autosaveIndicatorTarget.textContent = "Autosave failed"; return }
    if (this.saving) { this.autosaveIndicatorTarget.textContent = "Saving\u2026"; return }
    this.autosaveIndicatorTarget.textContent = this.dirty ? "Unsaved changes" : "\u2713 Saved"
  }

  // --- UI helpers ---
  setStatus(text) {
    const el = this.element.querySelector("[data-workflow-editor-status]")
    if (!el) return
    el.textContent = text
    window.clearTimeout(this.statusTimer)
    this.statusTimer = window.setTimeout(() => { el.textContent = "" }, 3000)
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
