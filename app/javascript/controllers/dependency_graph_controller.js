import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

// D3.js force-directed dependency graph for tasks
export default class extends Controller {
  static targets = ["container", "svg", "tooltip"]
  static values = { url: String }

  connect() {
    this.showLabels = true
    this.loadGraph()
  }

  disconnect() {
    if (this.simulation) this.simulation.stop()
  }

  async loadGraph() {
    try {
      const response = await fetch(this.urlValue)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.renderGraph(data)
    } catch (error) {
      console.error("Failed to load dependency graph:", error)
      this.svgTarget.innerHTML = `<text x="50%" y="50%" text-anchor="middle" fill="#888" font-size="14">Failed to load graph data</text>`
    }
  }

  renderGraph(data) {
    const svg = d3.select(this.svgTarget)
    const container = this.containerTarget
    const width = container.clientWidth
    const height = container.clientHeight

    svg.selectAll("*").remove()

    // If no nodes, show empty message
    if (!data.nodes.length) {
      svg.append("text")
        .attr("x", width / 2).attr("y", height / 2)
        .attr("text-anchor", "middle").attr("fill", "#888")
        .text("No tasks with dependencies found")
      return
    }

    // Filter to only show tasks involved in dependencies
    const linkedIds = new Set()
    data.links.forEach(l => { linkedIds.add(l.source); linkedIds.add(l.target) })
    const nodes = data.nodes.filter(n => linkedIds.has(n.id))
    const nodeIds = new Set(nodes.map(n => n.id))
    const links = data.links.filter(l => nodeIds.has(l.source) && nodeIds.has(l.target))

    if (!nodes.length) {
      svg.append("text")
        .attr("x", width / 2).attr("y", height / 2)
        .attr("text-anchor", "middle").attr("fill", "#888")
        .text("No dependencies to visualize")
      return
    }

    // Zoom behavior
    const g = svg.append("g")
    const zoom = d3.zoom()
      .scaleExtent([0.2, 5])
      .on("zoom", (event) => g.attr("transform", event.transform))
    svg.call(zoom)
    this._zoom = zoom
    this._svg = svg

    // Arrow marker for directed edges
    svg.append("defs").append("marker")
      .attr("id", "arrowhead")
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 22)
      .attr("refY", 0)
      .attr("markerWidth", 8)
      .attr("markerHeight", 8)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .attr("fill", "#555")

    // Force simulation
    this.simulation = d3.forceSimulation(nodes)
      .force("link", d3.forceLink(links).id(d => d.id).distance(120))
      .force("charge", d3.forceManyBody().strength(-400))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(30))

    // Links (edges)
    const link = g.append("g")
      .selectAll("line")
      .data(links)
      .join("line")
      .attr("stroke", "#555")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", 1.5)
      .attr("marker-end", "url(#arrowhead)")

    // Node groups
    const node = g.append("g")
      .selectAll("g")
      .data(nodes)
      .join("g")
      .call(d3.drag()
        .on("start", (event, d) => this.dragStart(event, d))
        .on("drag", (event, d) => this.dragging(event, d))
        .on("end", (event, d) => this.dragEnd(event, d)))
      .on("mouseenter", (event, d) => this.showTooltip(event, d))
      .on("mouseleave", () => this.hideTooltip())

    // Circles
    node.append("circle")
      .attr("r", d => d.blocked ? 14 : 12)
      .attr("fill", d => this.statusColor(d.status))
      .attr("stroke", d => d.blocked ? "#ef4444" : "rgba(255,255,255,0.15)")
      .attr("stroke-width", d => d.blocked ? 3 : 1.5)
      .attr("cursor", "grab")

    // Labels
    this._labels = node.append("text")
      .text(d => `#${d.id}`)
      .attr("dx", 16)
      .attr("dy", 4)
      .attr("font-size", 11)
      .attr("fill", "#ccc")
      .attr("pointer-events", "none")

    // Tick
    this.simulation.on("tick", () => {
      link
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y)

      node.attr("transform", d => `translate(${d.x},${d.y})`)
    })
  }

  statusColor(status) {
    const colors = {
      inbox: "#3b82f6",
      up_next: "#a855f7",
      in_progress: "#eab308",
      in_review: "#f97316",
      done: "#22c55e"
    }
    return colors[status] || "#6b7280"
  }

  dragStart(event, d) {
    if (!event.active) this.simulation.alphaTarget(0.3).restart()
    d.fx = d.x
    d.fy = d.y
  }

  dragging(event, d) {
    d.fx = event.x
    d.fy = event.y
  }

  dragEnd(event, d) {
    if (!event.active) this.simulation.alphaTarget(0)
    d.fx = null
    d.fy = null
  }

  showTooltip(event, d) {
    const tooltip = this.tooltipTarget
    tooltip.innerHTML = `
      <div class="font-semibold">#${d.id} — ${d.name}</div>
      <div class="text-xs text-content-muted mt-1">
        Status: <span class="font-medium">${d.status.replace(/_/g, ' ')}</span>
        ${d.blocked ? '<span class="text-red-400 ml-2">⚠️ Blocked</span>' : ''}
        ${d.model ? `<br>Model: ${d.model}` : ''}
      </div>
    `
    tooltip.classList.remove("hidden")
    tooltip.style.left = `${event.clientX + 12}px`
    tooltip.style.top = `${event.clientY - 10}px`
  }

  hideTooltip() {
    this.tooltipTarget.classList.add("hidden")
  }

  resetZoom() {
    if (this._svg && this._zoom) {
      this._svg.transition().duration(500).call(this._zoom.transform, d3.zoomIdentity)
    }
  }

  toggleLabels() {
    this.showLabels = !this.showLabels
    if (this._labels) {
      this._labels.attr("visibility", this.showLabels ? "visible" : "hidden")
    }
  }
}
