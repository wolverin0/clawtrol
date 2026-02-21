const STATUS_META = {
  inbox: { label: "Inbox", color: "#94a3b8", icon: "square" },
  up_next: { label: "Up Next", color: "#38bdf8", icon: "triangle" },
  in_progress: { label: "In Progress", color: "#f59e0b", icon: "diamond" },
  in_review: { label: "In Review", color: "#f472b6", icon: "circle" },
  done: { label: "Done", color: "#34d399", icon: "check" }
}

const HOTEL_THEME = {
  backdropTop: "#0b1120",
  backdropBottom: "#030712",
  backdropGlow: "rgba(56, 189, 248, 0.06)",
  vignette: "rgba(2, 6, 23, 0.56)",
  roomBase: "#0f172a",
  roomBorder: "rgba(148, 163, 184, 0.35)",
  roomInnerBorder: "rgba(226, 232, 240, 0.08)",
  roomShadow: "rgba(2, 6, 23, 0.55)",
  headerText: "#f8fafc",
  headerMuted: "#dbe7ff",
  labelText: "#f8fafc",
  labelMuted: "#94a3b8",
  taskLabelBg: "rgba(2, 6, 23, 0.92)",
  taskLabelBorder: "rgba(148, 163, 184, 0.24)",
  hoverOutline: "#f8fafc"
}

export class CodemapHotelRenderer {
  constructor(canvas, options = {}) {
    this.canvas = canvas
    this.ctx = canvas.getContext("2d")
    this.assetBasePath = options.assetBasePath || "/codemap"

    this.tasks = []
    this.hitTargets = []
    this.hoveredTaskId = null

    this.atlas = null
    this.textureCache = new Map()
    this.patternCache = new Map()

    this._needsRender = true
    this._raf = null
    this.renderLoop = this.renderLoop.bind(this)
    this._raf = requestAnimationFrame(this.renderLoop)

    this.bootAssets()
  }

  destroy() {
    if (this._raf) cancelAnimationFrame(this._raf)
  }

  async bootAssets() {
    try {
      const res = await fetch(`${this.assetBasePath}/meta/atlas.json`)
      if (res.ok) {
        this.atlas = await res.json()
        await this.preloadAtlasTextures()
      }
    } catch {
      // keep fallback renderer active
    }
    this.requestRender()
  }

  async preloadAtlasTextures() {
    const files = Object.values(this.atlas?.files || {})
    await Promise.all(files.map((path) => this.loadTexture(path)))
  }

  loadTexture(path) {
    if (!path) return Promise.resolve(null)
    if (this.textureCache.has(path)) return Promise.resolve(this.textureCache.get(path))

    return new Promise((resolve) => {
      const img = new Image()
      img.onload = () => {
        this.textureCache.set(path, img)
        this.patternCache.clear()
        this.requestRender()
        resolve(img)
      }
      img.onerror = () => {
        this.textureCache.set(path, null)
        resolve(null)
      }
      img.src = encodeURI(`${this.assetBasePath}/raw_assets/${path}`)
    })
  }

  resize(width, height) {
    if (!width || !height) return
    this.canvas.width = Math.max(1, Math.floor(width))
    this.canvas.height = Math.max(1, Math.floor(height))
    this.requestRender()
  }

  setTasks(tasks = []) {
    if (!Array.isArray(tasks)) {
      this.tasks = []
      this.requestRender()
      return
    }

    this.tasks = tasks.map((task) => this.normalizeTask(task))
    this.requestRender()
  }

  setHoveredTask(id) {
    const normalized = id == null ? null : String(id)
    if (this.hoveredTaskId === normalized) return
    this.hoveredTaskId = normalized
    this.requestRender()
  }

  updateTaskStatus(id, status) {
    const taskId = String(id)
    const task = this.tasks.find((entry) => entry.id === taskId)
    if (!task) return false

    const normalized = this.normalizeStatus(status)
    if (task.status === normalized) return false
    task.status = normalized
    this.requestRender()
    return true
  }

  removeTask(id) {
    const taskId = String(id)
    const nextTasks = this.tasks.filter((task) => task.id !== taskId)
    if (nextTasks.length === this.tasks.length) return false
    this.tasks = nextTasks
    this.requestRender()
    return true
  }

  pickTaskAt(x, y) {
    return this.hitTargets.find((target) => {
      return x >= target.x && x <= target.x + target.w && y >= target.y && y <= target.y + target.h
    })
  }

  requestRender() {
    this._needsRender = true
  }

  renderLoop() {
    if (this._needsRender) {
      this.render()
      this._needsRender = false
    }
    this._raf = requestAnimationFrame(this.renderLoop)
  }

  render() {
    const { ctx, canvas } = this
    if (!canvas.width || !canvas.height) return

    ctx.clearRect(0, 0, canvas.width, canvas.height)
    this.drawBackdrop()

    const rooms = this.computeRooms()
    const roomTasks = new Map()
    rooms.forEach((room) => {
      roomTasks.set(
        room.status,
        this.tasks.filter((task) => task.status === room.status)
      )
    })

    rooms.forEach((room) => this.drawRoom(room, roomTasks.get(room.status) || []))
    this.drawTasks(rooms, roomTasks)
    this.drawLobbySign()
  }

  drawBackdrop() {
    const { ctx, canvas } = this
    const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height)
    gradient.addColorStop(0, HOTEL_THEME.backdropTop)
    gradient.addColorStop(1, HOTEL_THEME.backdropBottom)
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    const glow = ctx.createRadialGradient(
      canvas.width * 0.25,
      canvas.height * 0.2,
      0,
      canvas.width * 0.25,
      canvas.height * 0.2,
      canvas.width * 0.8
    )
    glow.addColorStop(0, HOTEL_THEME.backdropGlow)
    glow.addColorStop(1, "rgba(0, 0, 0, 0)")
    ctx.fillStyle = glow
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    ctx.strokeStyle = "rgba(148, 163, 184, 0.06)"
    ctx.lineWidth = 1
    for (let y = 0; y < canvas.height; y += 26) {
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(canvas.width, y)
      ctx.stroke()
    }

    const vignette = ctx.createRadialGradient(
      canvas.width / 2,
      canvas.height / 2,
      canvas.width * 0.2,
      canvas.width / 2,
      canvas.height / 2,
      canvas.width * 0.9
    )
    vignette.addColorStop(0, "rgba(0, 0, 0, 0)")
    vignette.addColorStop(1, HOTEL_THEME.vignette)
    ctx.fillStyle = vignette
    ctx.fillRect(0, 0, canvas.width, canvas.height)
  }

  computeRooms() {
    const { canvas } = this
    const padding = Math.max(20, Math.floor(Math.min(canvas.width, canvas.height) * 0.06))
    const gap = Math.max(14, Math.floor(Math.min(canvas.width, canvas.height) * 0.035))
    const rowHeight = Math.max(120, Math.floor((canvas.height - padding * 2 - gap) / 2))
    const rowWidth = Math.max(1, canvas.width - padding * 2)

    const row1RoomWidth = Math.max(1, Math.floor((rowWidth - gap * 2) / 3))
    const row2RoomWidth = Math.max(1, Math.floor((rowWidth - gap) / 2))

    const row1Y = padding
    const row2Y = padding + rowHeight + gap

    const rooms = []
    rooms.push(this.buildRoom("inbox", padding, row1Y, row1RoomWidth, rowHeight))
    rooms.push(this.buildRoom("up_next", padding + row1RoomWidth + gap, row1Y, row1RoomWidth, rowHeight))
    rooms.push(this.buildRoom("in_progress", padding + (row1RoomWidth + gap) * 2, row1Y, row1RoomWidth, rowHeight))

    const row2TotalWidth = row2RoomWidth * 2 + gap
    const row2X = padding + Math.max(0, (rowWidth - row2TotalWidth) / 2)

    rooms.push(this.buildRoom("in_review", row2X, row2Y, row2RoomWidth, rowHeight))
    rooms.push(this.buildRoom("done", row2X + row2RoomWidth + gap, row2Y, row2RoomWidth, rowHeight))

    return rooms
  }

  buildRoom(status, x, y, w, h) {
    const meta = STATUS_META[status]
    const labelHeight = Math.max(28, Math.floor(h * 0.2))
    const innerPadding = Math.max(12, Math.floor(Math.min(w, h) * 0.08))
    const radius = Math.max(12, Math.floor(Math.min(w, h) * 0.06))
    return {
      status,
      label: meta.label,
      color: meta.color,
      icon: meta.icon,
      x,
      y,
      w,
      h,
      labelHeight,
      innerPadding,
      radius
    }
  }

  drawRoom(room, tasks = []) {
    const { ctx } = this
    const floorRegion = this.tileRegionFor("floor")
    const radius = room.radius

    ctx.save()
    ctx.shadowColor = HOTEL_THEME.roomShadow
    ctx.shadowBlur = 18
    ctx.shadowOffsetY = 8
    ctx.fillStyle = HOTEL_THEME.roomBase
    this.roundedRect(ctx, room.x, room.y, room.w, room.h, radius)
    ctx.fill()
    ctx.restore()

    ctx.save()
    this.roundedRect(ctx, room.x, room.y, room.w, room.h, radius)
    ctx.clip()
    ctx.fillStyle = HOTEL_THEME.roomBase
    ctx.fillRect(room.x, room.y, room.w, room.h)

    if (floorRegion) {
      const pattern = this.patternForRegion(floorRegion)
      if (pattern) {
        ctx.globalAlpha = 0.035
        ctx.fillStyle = pattern
        ctx.fillRect(room.x, room.y, room.w, room.h)
      }
    }

    const accentGradient = ctx.createLinearGradient(room.x, room.y, room.x, room.y + room.h)
    accentGradient.addColorStop(0, this.withAlpha(room.color, 0.14))
    accentGradient.addColorStop(1, this.withAlpha(room.color, 0.04))
    ctx.globalAlpha = 1
    ctx.fillStyle = accentGradient
    ctx.fillRect(room.x, room.y, room.w, room.h)
    ctx.restore()

    ctx.strokeStyle = this.withAlpha(room.color, 0.42)
    ctx.lineWidth = 1.6
    this.roundedRect(ctx, room.x, room.y, room.w, room.h, radius)
    ctx.stroke()

    ctx.strokeStyle = HOTEL_THEME.roomInnerBorder
    ctx.lineWidth = 1
    this.roundedRect(ctx, room.x + 1.5, room.y + 1.5, room.w - 3, room.h - 3, Math.max(0, radius - 1))
    ctx.stroke()

    const headerX = room.x + room.innerPadding
    const headerY = room.y + room.innerPadding * 0.5
    const headerW = room.w - room.innerPadding * 2
    const headerH = room.labelHeight
    const headerRadius = Math.min(10, headerH / 2)

    const headerGradient = ctx.createLinearGradient(0, headerY, 0, headerY + headerH)
    headerGradient.addColorStop(0, this.withAlpha(room.color, 0.48))
    headerGradient.addColorStop(1, "rgba(15, 23, 42, 0.94)")
    ctx.fillStyle = headerGradient
    this.roundedRect(ctx, headerX, headerY, headerW, headerH, headerRadius)
    ctx.fill()

    ctx.strokeStyle = this.withAlpha(room.color, 0.44)
    ctx.lineWidth = 1
    this.roundedRect(ctx, headerX, headerY, headerW, headerH, headerRadius)
    ctx.stroke()

    const iconSize = headerH * 0.26
    const iconX = headerX + iconSize + 6
    const iconY = headerY + headerH / 2
    this.drawStatusIcon(room.icon, iconX, iconY, iconSize, room.color)

    ctx.fillStyle = HOTEL_THEME.headerText
    ctx.font = "700 12px ui-sans-serif, system-ui, sans-serif"
    ctx.textBaseline = "middle"
    ctx.textAlign = "left"
    ctx.fillText(room.label, iconX + iconSize + 7, headerY + headerH / 2)

    const count = tasks.length
    const countText = `${count} ${count === 1 ? "task" : "tasks"}`
    ctx.fillStyle = HOTEL_THEME.headerMuted
    ctx.font = "600 11px ui-sans-serif, system-ui, sans-serif"
    ctx.textAlign = "right"
    ctx.fillText(countText, headerX + headerW - 8, headerY + headerH / 2)
  }

  drawTasks(rooms, roomTasks) {
    this.hitTargets = []
    rooms.forEach((room) => {
      const tasks = roomTasks?.get(room.status) || []
      const slots = this.computeSlots(room, tasks.length)
      tasks.forEach((task, index) => {
        const slot = slots[index]
        if (!slot) return
        this.drawTask(task, slot, room)
      })
    })
  }

  computeSlots(room, count) {
    if (count === 0) return []
    const availableWidth = room.w - room.innerPadding * 2
    const availableHeight = room.h - room.innerPadding * 2 - room.labelHeight

    let slot = Math.max(28, Math.floor(Math.min(room.w, room.h) * 0.125))
    let cols = Math.max(1, Math.floor(availableWidth / slot))
    let rows = Math.max(1, Math.floor(availableHeight / slot))

    while (cols * rows < count && slot > 18) {
      slot -= 2
      cols = Math.max(1, Math.floor(availableWidth / slot))
      rows = Math.max(1, Math.floor(availableHeight / slot))
    }

    if (cols * rows < count) {
      rows = Math.ceil(count / cols)
      const adjusted = Math.floor(availableHeight / rows)
      slot = Math.max(16, Math.min(slot, adjusted))
      cols = Math.max(1, Math.floor(availableWidth / slot))
    }

    const slots = []
    for (let index = 0; index < count; index += 1) {
      const col = index % cols
      const row = Math.floor(index / cols)
      const x = room.x + room.innerPadding + col * slot + slot / 2
      const y = room.y + room.labelHeight + room.innerPadding + row * slot + slot / 2
      slots.push({ x, y, size: slot })
    }
    return slots
  }

  drawTask(task, slot, room) {
    const { ctx } = this
    const meta = STATUS_META[task.status] || STATUS_META.inbox
    const isHovered = this.hoveredTaskId === task.id
    const size = slot.size
    const spriteRegion = this.spriteRegionFor(task.status)

    const spriteSize = size * 0.72
    const spriteX = slot.x - spriteSize / 2
    const spriteY = slot.y - spriteSize / 2
    const ringRadius = size * (isHovered ? 0.62 : 0.55)

    ctx.save()
    ctx.shadowColor = "rgba(2, 6, 23, 0.6)"
    ctx.shadowBlur = isHovered ? 12 : 7
    ctx.shadowOffsetY = 2
    ctx.fillStyle = this.withAlpha(meta.color, isHovered ? 0.32 : 0.22)
    ctx.beginPath()
    ctx.arc(slot.x, slot.y, ringRadius, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()

    ctx.strokeStyle = this.withAlpha(meta.color, isHovered ? 0.94 : 0.66)
    ctx.lineWidth = Math.max(1.2, size * (isHovered ? 0.12 : 0.08))
    ctx.beginPath()
    ctx.arc(slot.x, slot.y, ringRadius, 0, Math.PI * 2)
    ctx.stroke()

    if (!this.drawRegion(spriteRegion, spriteX, spriteY, spriteSize, spriteSize)) {
      ctx.fillStyle = meta.color
      ctx.fillRect(spriteX + spriteSize * 0.2, spriteY + spriteSize * 0.2, spriteSize * 0.6, spriteSize * 0.6)
    }

    const label = this.truncateLabel(task.name, 20)
    const fontSize = Math.max(10, Math.floor(size * 0.38))
    ctx.font = `700 ${fontSize}px ui-sans-serif, system-ui, sans-serif`
    ctx.textBaseline = "middle"
    ctx.textAlign = "left"

    const textWidth = ctx.measureText(label).width
    const labelHeight = Math.max(16, Math.floor(size * 0.66))
    const labelPadding = Math.max(8, Math.floor(size * 0.24))
    const labelWidth = Math.min(room.w - room.innerPadding * 2, textWidth + labelHeight + labelPadding * 2)

    let labelX = slot.x - labelWidth / 2
    let labelY = spriteY + spriteSize + 6

    const minX = room.x + room.innerPadding
    const maxX = room.x + room.w - room.innerPadding - labelWidth
    labelX = Math.max(minX, Math.min(labelX, maxX))

    const maxY = room.y + room.h - room.innerPadding - labelHeight
    if (labelY > maxY) labelY = spriteY - labelHeight - 6

    ctx.fillStyle = HOTEL_THEME.taskLabelBg
    this.roundedRect(ctx, labelX, labelY, labelWidth, labelHeight, 6)
    ctx.fill()

    ctx.strokeStyle = isHovered ? this.withAlpha(HOTEL_THEME.hoverOutline, 0.55) : HOTEL_THEME.taskLabelBorder
    ctx.lineWidth = isHovered ? 1.4 : 1
    this.roundedRect(ctx, labelX, labelY, labelWidth, labelHeight, 6)
    ctx.stroke()

    this.drawStatusIcon(meta.icon, labelX + labelHeight / 2, labelY + labelHeight / 2, labelHeight * 0.32, meta.color)

    ctx.fillStyle = HOTEL_THEME.labelText
    ctx.fillText(label, labelX + labelHeight, labelY + labelHeight / 2)

    const hitX = Math.min(spriteX, labelX)
    const hitY = Math.min(spriteY, labelY)
    const hitW = Math.max(spriteX + spriteSize, labelX + labelWidth) - hitX
    const hitH = Math.max(spriteY + spriteSize, labelY + labelHeight) - hitY

    this.hitTargets.push({
      id: task.id,
      url: task.url,
      x: hitX,
      y: hitY,
      w: hitW,
      h: hitH
    })
  }

  drawLobbySign() {
    const { ctx, canvas } = this
    const signWidth = Math.min(260, Math.floor(canvas.width * 0.36))
    const signHeight = 24
    const signX = canvas.width / 2 - signWidth / 2
    const signY = canvas.height - signHeight - 8

    ctx.fillStyle = "rgba(2, 6, 23, 0.76)"
    this.roundedRect(ctx, signX, signY, signWidth, signHeight, 10)
    ctx.fill()

    ctx.strokeStyle = "rgba(148, 163, 184, 0.26)"
    ctx.lineWidth = 1
    this.roundedRect(ctx, signX, signY, signWidth, signHeight, 10)
    ctx.stroke()

    ctx.fillStyle = HOTEL_THEME.labelMuted
    ctx.font = "700 11px ui-sans-serif, system-ui, sans-serif"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText("ClawTrol Codemap Hotel", canvas.width / 2, signY + signHeight / 2)
  }

  tileRegionFor(key) {
    return this.atlas?.tile_regions?.[key] || null
  }

  spriteRegionFor(status) {
    if (!this.atlas) return null
    const spriteKey = status === "done" ? "guard" : "snake"
    return this.atlas.sprite_regions?.[spriteKey] || this.atlas.sprite_regions?.snake || null
  }

  drawRegion(region, dx, dy, dw, dh) {
    if (!region) return false
    const img = this.textureCache.get(region.file)
    if (!img || !img.complete || img.naturalWidth === 0) return false

    this.ctx.drawImage(img, region.x || 0, region.y || 0, region.w, region.h, dx, dy, dw, dh)
    return true
  }

  patternForRegion(region) {
    if (!region) return null
    const key = `${region.file}:${region.x}:${region.y}:${region.w}:${region.h}`
    if (this.patternCache.has(key)) return this.patternCache.get(key)

    const img = this.textureCache.get(region.file)
    if (!img || !img.complete || img.naturalWidth === 0) return null

    const tile = document.createElement("canvas")
    tile.width = region.w
    tile.height = region.h
    const tileCtx = tile.getContext("2d")
    tileCtx.drawImage(img, region.x || 0, region.y || 0, region.w, region.h, 0, 0, region.w, region.h)
    const pattern = this.ctx.createPattern(tile, "repeat")
    this.patternCache.set(key, pattern)
    return pattern
  }

  drawStatusIcon(icon, x, y, size, color) {
    const { ctx } = this
    ctx.save()
    ctx.translate(x, y)
    ctx.fillStyle = color
    ctx.strokeStyle = color
    ctx.lineWidth = 2

    switch (icon) {
      case "triangle":
        ctx.beginPath()
        ctx.moveTo(0, -size)
        ctx.lineTo(size, size)
        ctx.lineTo(-size, size)
        ctx.closePath()
        ctx.fill()
        break
      case "diamond":
        ctx.beginPath()
        ctx.moveTo(0, -size)
        ctx.lineTo(size, 0)
        ctx.lineTo(0, size)
        ctx.lineTo(-size, 0)
        ctx.closePath()
        ctx.fill()
        break
      case "check":
        ctx.beginPath()
        ctx.arc(0, 0, size, 0, Math.PI * 2)
        ctx.stroke()
        ctx.beginPath()
        ctx.moveTo(-size * 0.5, 0)
        ctx.lineTo(-size * 0.1, size * 0.4)
        ctx.lineTo(size * 0.6, -size * 0.4)
        ctx.stroke()
        break
      case "circle":
        ctx.beginPath()
        ctx.arc(0, 0, size, 0, Math.PI * 2)
        ctx.fill()
        break
      case "square":
      default:
        ctx.fillRect(-size, -size, size * 2, size * 2)
        break
    }

    ctx.restore()
  }

  roundedRect(ctx, x, y, w, h, r) {
    const radius = Math.min(r, w / 2, h / 2)
    ctx.beginPath()
    ctx.moveTo(x + radius, y)
    ctx.arcTo(x + w, y, x + w, y + h, radius)
    ctx.arcTo(x + w, y + h, x, y + h, radius)
    ctx.arcTo(x, y + h, x, y, radius)
    ctx.arcTo(x, y, x + w, y, radius)
    ctx.closePath()
  }

  truncateLabel(label, max) {
    const text = String(label || "")
    if (text.length <= max) return text
    return `${text.slice(0, Math.max(1, max - 1)).trimEnd()}…`
  }

  normalizeTask(task) {
    return {
      id: String(task.id),
      name: task.name || `Task ${task.id}`,
      status: this.normalizeStatus(task.status),
      url: task.url || "#",
      board_id: task.board_id || null,
      board_name: task.board_name || null
    }
  }

  normalizeStatus(status) {
    const key = String(status || "").toLowerCase()
    return STATUS_META[key] ? key : "inbox"
  }

  withAlpha(hex, alpha) {
    const raw = String(hex || "").replace("#", "")
    if (raw.length !== 6 && raw.length !== 3) return `rgba(15, 23, 42, ${alpha})`

    const normalized = raw.length === 3 ? raw.split("").map((c) => c + c).join("") : raw
    const num = Number.parseInt(normalized, 16)
    const r = (num >> 16) & 255
    const g = (num >> 8) & 255
    const b = num & 255
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
