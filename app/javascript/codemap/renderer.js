export class CodemapRenderer {
  constructor(canvas, options = {}) {
    this.canvas = canvas
    this.ctx = canvas.getContext("2d")
    this.assetBasePath = options.assetBasePath || "/codemap"

    this.map = {
      width: options.mapWidth || 32,
      height: options.mapHeight || 20,
      tileSize: options.tileSize || 16
    }

    this.camera = { x: 0, y: 0, zoom: 1 }
    this.selection = null
    this.debugOverlay = false
    this.lastSeq = -1

    this.tiles = new Map()
    this.sprites = new Map()

    this.loadedTiles = new Map()
    this.loadedSprites = new Map()

    this.atlas = null
    this.textureCache = new Map()
    this.bootAssets()

    this._needsRender = true
    this._raf = null
    this.renderLoop = this.renderLoop.bind(this)
    this._raf = requestAnimationFrame(this.renderLoop)
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

  resetCamera() {
    this.camera = { x: 0, y: 0, zoom: 1 }
    this.requestRender()
  }

  setDebugOverlay(enabled) {
    this.debugOverlay = !!enabled
    this.requestRender()
  }

  applyEvent(payload = {}) {
    const seq = Number(payload.seq ?? payload.sequence ?? -1)
    if (Number.isFinite(seq) && seq >= 0) {
      if (seq <= this.lastSeq) return false
      this.lastSeq = seq
    }

    const eventType = payload.event || payload.type
    const data = payload.data || payload

    switch (eventType) {
      case "state_sync":
        this.applyStateSync(data)
        break
      case "tile_patch":
        this.applyTilePatch(data)
        break
      case "sprite_patch":
        this.applySpritePatch(data)
        break
      case "camera":
        this.applyCamera(data)
        break
      case "selection":
        this.selection = data.selection || data
        break
      case "debug_overlay":
        this.debugOverlay = data.enabled ?? data.debug ?? !this.debugOverlay
        break
      default:
        return false
    }

    this.requestRender()
    return true
  }

  applyStateSync(data = {}) {
    if (data.map) {
      this.map.width = data.map.width || this.map.width
      this.map.height = data.map.height || this.map.height
      this.map.tileSize = data.map.tile_size || data.map.tileSize || this.map.tileSize
    }

    this.tiles.clear()
    this.sprites.clear()

    ;(data.tiles || []).forEach((tile) => this.upsertTile(tile))
    ;(data.sprites || []).forEach((sprite) => this.upsertSprite(sprite))

    if (data.camera) this.applyCamera(data.camera)
    if (data.selection) this.selection = data.selection
    if (data.debug_overlay !== undefined) this.debugOverlay = !!data.debug_overlay
  }

  applyTilePatch(data = {}) {
    const patches = data.tiles || (data.x !== undefined ? [data] : [])
    patches.forEach((tile) => this.upsertTile(tile))
  }

  applySpritePatch(data = {}) {
    ;(data.sprites || []).forEach((sprite) => this.upsertSprite(sprite))
    ;(data.delete_ids || []).forEach((id) => this.sprites.delete(String(id)))
  }

  applyCamera(data = {}) {
    this.camera.x = Number(data.x ?? this.camera.x)
    this.camera.y = Number(data.y ?? this.camera.y)
    this.camera.zoom = Number(data.zoom ?? this.camera.zoom) || 1
  }

  upsertTile(tile = {}) {
    if (tile.x === undefined || tile.y === undefined) return
    const key = `${tile.x},${tile.y}`
    this.tiles.set(key, {
      x: Number(tile.x),
      y: Number(tile.y),
      tile_id: tile.tile_id || tile.tileId || null,
      atlas_key: tile.atlas_key || null,
      color: tile.color || null
    })
    if (tile.tile_id) this.preloadTile(tile.tile_id)
  }

  upsertSprite(sprite = {}) {
    if (!sprite.id) return
    this.sprites.set(String(sprite.id), {
      id: String(sprite.id),
      x: Number(sprite.x || 0),
      y: Number(sprite.y || 0),
      sprite_id: sprite.sprite_id || sprite.spriteId || null,
      atlas_key: sprite.atlas_key || null,
      color: sprite.color || null,
      label: sprite.label || null
    })
    if (sprite.sprite_id) this.preloadSprite(sprite.sprite_id)
  }

  preloadTile(id) {
    if (this.loadedTiles.has(id)) return
    const img = new Image()
    img.onload = () => this.requestRender()
    img.onerror = () => this.loadedTiles.set(id, null)
    img.src = `${this.assetBasePath}/tiles/${id}.png`
    this.loadedTiles.set(id, img)
  }

  preloadSprite(id) {
    if (this.loadedSprites.has(id)) return
    const img = new Image()
    img.onload = () => this.requestRender()
    img.onerror = () => this.loadedSprites.set(id, null)
    img.src = `${this.assetBasePath}/sprites/${id}.png`
    this.loadedSprites.set(id, img)
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
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    const size = this.map.tileSize * this.camera.zoom
    const offsetX = -this.camera.x * size
    const offsetY = -this.camera.y * size

    this.drawGrid(size, offsetX, offsetY)
    this.drawTiles(size, offsetX, offsetY)
    this.drawSprites(size, offsetX, offsetY)
    this.drawSelection(size, offsetX, offsetY)

    if (this.debugOverlay) this.drawDebugOverlay()
  }

  drawGrid(size, offsetX, offsetY) {
    const { ctx, canvas } = this
    ctx.strokeStyle = "rgba(120,120,120,0.25)"
    ctx.lineWidth = 1

    for (let y = 0; y <= this.map.height; y += 1) {
      const py = Math.floor(offsetY + y * size) + 0.5
      ctx.beginPath()
      ctx.moveTo(0, py)
      ctx.lineTo(canvas.width, py)
      ctx.stroke()
    }

    for (let x = 0; x <= this.map.width; x += 1) {
      const px = Math.floor(offsetX + x * size) + 0.5
      ctx.beginPath()
      ctx.moveTo(px, 0)
      ctx.lineTo(px, canvas.height)
      ctx.stroke()
    }
  }

  tileRegionFor(tile) {
    if (!this.atlas) return null

    if (tile.atlas_key && this.atlas.tile_regions?.[tile.atlas_key]) {
      return this.atlas.tile_regions[tile.atlas_key]
    }

    const index = Number(tile.tile_id)
    if (!Number.isNaN(index) && this.atlas.tile_sheet) {
      const t = this.atlas.tile_sheet
      const cols = Math.max(1, Math.floor(t.width / t.tile_w))
      return {
        file: t.file,
        x: (index % cols) * t.tile_w,
        y: Math.floor(index / cols) * t.tile_h,
        w: t.tile_w,
        h: t.tile_h
      }
    }

    return this.atlas.tile_regions?.default || null
  }

  spriteRegionFor(sprite) {
    if (!this.atlas) return null

    const key = sprite.atlas_key || sprite.sprite_id
    if (key && this.atlas.sprite_regions?.[key]) {
      return this.atlas.sprite_regions[key]
    }

    const index = Number(sprite.sprite_id)
    if (!Number.isNaN(index) && this.atlas.sprite_sheet) {
      const s = this.atlas.sprite_sheet
      const cols = Math.max(1, Math.floor(s.width / s.tile_w))
      return {
        file: s.file,
        x: (index % cols) * s.tile_w,
        y: Math.floor(index / cols) * s.tile_h,
        w: s.tile_w,
        h: s.tile_h
      }
    }

    return this.atlas.sprite_regions?.snake || null
  }

  drawRegion(region, dx, dy, dw, dh) {
    if (!region) return false
    const img = this.textureCache.get(region.file)
    if (!img || !img.complete || img.naturalWidth === 0) return false

    this.ctx.drawImage(img, region.x || 0, region.y || 0, region.w, region.h, dx, dy, dw, dh)
    return true
  }

  drawTiles(size, offsetX, offsetY) {
    const { ctx } = this
    this.tiles.forEach((tile) => {
      const x = offsetX + tile.x * size
      const y = offsetY + tile.y * size

      const region = this.tileRegionFor(tile)
      if (this.drawRegion(region, x, y, size, size)) return

      const img = tile.tile_id ? this.loadedTiles.get(tile.tile_id) : null
      if (img && img.complete && img.naturalWidth > 0) {
        ctx.drawImage(img, x, y, size, size)
      } else {
        ctx.fillStyle = tile.color || "#334155"
        ctx.fillRect(x, y, size, size)
      }
    })
  }

  drawSprites(size, offsetX, offsetY) {
    const { ctx } = this
    this.sprites.forEach((sprite) => {
      const x = offsetX + sprite.x * size
      const y = offsetY + sprite.y * size

      const region = this.spriteRegionFor(sprite)
      if (!this.drawRegion(region, x, y, size, size)) {
        const img = sprite.sprite_id ? this.loadedSprites.get(sprite.sprite_id) : null
        if (img && img.complete && img.naturalWidth > 0) {
          ctx.drawImage(img, x, y, size, size)
        } else {
          ctx.fillStyle = sprite.color || "#22d3ee"
          ctx.fillRect(x + size * 0.1, y + size * 0.1, size * 0.8, size * 0.8)
        }
      }

      if (this.debugOverlay && sprite.label) {
        ctx.fillStyle = "#e2e8f0"
        ctx.font = "10px ui-monospace, monospace"
        ctx.fillText(sprite.label, x, y - 2)
      }
    })
  }

  drawSelection(size, offsetX, offsetY) {
    if (!this.selection) return
    const { ctx } = this
    const sx = offsetX + Number(this.selection.x || 0) * size
    const sy = offsetY + Number(this.selection.y || 0) * size
    const sw = Number(this.selection.w || 1) * size
    const sh = Number(this.selection.h || 1) * size

    ctx.strokeStyle = "#f59e0b"
    ctx.lineWidth = 2
    ctx.strokeRect(sx, sy, sw, sh)
  }

  drawDebugOverlay() {
    const { ctx } = this
    ctx.fillStyle = "rgba(15, 23, 42, 0.75)"
    ctx.fillRect(8, 8, 280, 70)
    ctx.fillStyle = "#e2e8f0"
    ctx.font = "11px ui-monospace, monospace"
    ctx.fillText(`seq: ${this.lastSeq}`, 14, 24)
    ctx.fillText(`tiles: ${this.tiles.size} sprites: ${this.sprites.size}`, 14, 40)
    ctx.fillText(`cam: ${this.camera.x},${this.camera.y} z=${this.camera.zoom.toFixed(2)}`, 14, 54)
    ctx.fillText(`atlas: ${this.atlas ? "raw_assets loaded" : "fallback"}`, 14, 68)
  }
}
