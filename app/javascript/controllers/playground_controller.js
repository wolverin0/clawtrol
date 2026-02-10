import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    // Image generation
    "prompt", "model", "product", "template", "size", "generateBtn", "generateText", "generateSpinner",
    "imagePreview", "useImageBtn", "gallery",
    "variantsBtn", "variantsText", "variantsSpinner", "variantsContainer", "variantsRow",
    // Post composer
    "dropZone", "dropZonePlaceholder", "postImage", "fileInput",
    "platformFb", "platformIg", "caption", "charCount",
    "hashtagContainer", "hashtagInput", "cta",
    // Previews
    "fbPreviewContainer", "fbCaption", "fbImage", "fbImagePlaceholder",
    "igPreviewContainer", "igCaption", "igImage", "igImagePlaceholder",
    // Actions
    "downloadBtn", "toast", "toastMessage",
    // Content Library
    "contentGallery", "galleryCount", "typeFilter",
    "filterAll", "filterCrm", "filterFitness", "filterDelivery", "filterFutura",
    // Lightbox
    "lightbox", "lightboxImage", "lightboxVideo", 
    "lightboxProduct", "lightboxType", "lightboxDimensions",
    "lightboxBatch", "lightboxPrompt"
  ]

  connect() {
    this.platforms = { facebook: true, instagram: true }
    this.hashtags = []
    this.currentImageData = null
    this.generatedImages = []
    
    // Content library state
    this.allContent = []
    this.filteredContent = []
    this.activeProduct = "all"
    this.activeType = "all"
    this.currentLightboxItem = null
    this.approvedItems = []
    
    this.loadGallery()
    this.loadDraftOnStartup()
    this.updatePlatformUI()
    this.loadContentLibrary()
  }

  // === CONTENT LIBRARY ===
  
  async loadContentLibrary() {
    try {
      const response = await fetch("/marketing/generated_content", {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) throw new Error(`Failed to load content: ${response.status}`)
      
      const data = await response.json()
      this.allContent = data.batches || []
      this.approvedItems = this.loadApprovedItems()
      this.applyFilters()
    } catch (error) {
      console.error("Failed to load content library:", error)
      if (this.hasContentGalleryTarget) {
        this.contentGalleryTarget.innerHTML = `
          <div class="col-span-full text-center py-12 text-content-muted">
            <div class="text-4xl mb-2">⚠️</div>
            <p>Failed to load content library</p>
            <p class="text-sm mt-2">${error.message}</p>
          </div>
        `
      }
    }
  }
  
  loadApprovedItems() {
    try {
      const saved = localStorage.getItem("playground_approved_content")
      return saved ? JSON.parse(saved) : []
    } catch {
      return []
    }
  }
  
  saveApprovedItems() {
    try {
      localStorage.setItem("playground_approved_content", JSON.stringify(this.approvedItems))
    } catch (e) {
      console.warn("Could not save approved items:", e)
    }
  }

  applyFilters() {
    this.filteredContent = []
    
    this.allContent.forEach(batch => {
      batch.images.forEach(image => {
        // Product filter
        if (this.activeProduct !== "all" && image.product !== this.activeProduct) return
        
        // Type filter
        if (this.activeType !== "all" && image.type !== this.activeType) return
        
        this.filteredContent.push({ ...image, batch: batch.name, batchDate: batch.generated_at })
      })
    })
    
    this.renderContentGallery()
    this.updateFilterUI()
  }

  renderContentGallery() {
    if (!this.hasContentGalleryTarget) return
    
    const count = this.filteredContent.length
    if (this.hasGalleryCountTarget) {
      this.galleryCountTarget.textContent = `(${count} item${count !== 1 ? "s" : ""})`
    }
    
    if (count === 0) {
      this.contentGalleryTarget.innerHTML = `
        <div class="col-span-full text-center py-12 text-content-muted">
          <div class="text-4xl mb-2">📭</div>
          <p>No content matches your filters</p>
        </div>
      `
      return
    }
    
    this.contentGalleryTarget.innerHTML = this.filteredContent.map((item, index) => {
      const isVideo = item.type === "video" || item.url.match(/\.(mp4|webm|mov)$/i)
      const isApproved = this.isApproved(item)
      const productColors = {
        futuracrm: "border-blue-500/50 bg-blue-500/10",
        futurafitness: "border-green-500/50 bg-green-500/10",
        optimadelivery: "border-orange-500/50 bg-orange-500/10",
        futura: "border-purple-500/50 bg-purple-500/10"
      }
      const productBadgeColors = {
        futuracrm: "bg-blue-500",
        futurafitness: "bg-green-500",
        optimadelivery: "bg-orange-500",
        futura: "bg-purple-500"
      }
      const borderClass = productColors[item.product] || "border-border"
      const badgeColor = productBadgeColors[item.product] || "bg-gray-500"
      
      return `
        <button 
          class="group relative aspect-square rounded-lg overflow-hidden border-2 ${borderClass} hover:border-accent transition-all hover:scale-105 hover:shadow-lg"
          data-action="click->playground#openLightbox"
          data-index="${index}"
        >
          ${isVideo ? `
            <video src="${item.url}" class="w-full h-full object-cover" muted preload="metadata"></video>
            <div class="absolute inset-0 flex items-center justify-center bg-black/30">
              <span class="text-4xl">▶️</span>
            </div>
          ` : `
            <img src="${item.url}" class="w-full h-full object-cover" alt="${item.filename}" loading="lazy" />
          `}
          ${isApproved ? `
            <div class="absolute top-2 right-2 bg-green-500 text-white text-xs px-2 py-1 rounded-full flex items-center gap-1">
              <span>✓</span> Approved
            </div>
          ` : ''}
          <div class="absolute top-2 left-2">
            <span class="${badgeColor} text-white text-xs px-2 py-0.5 rounded">${item.product}</span>
          </div>
          <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/70 to-transparent p-2 opacity-0 group-hover:opacity-100 transition-opacity">
            <p class="text-white text-xs truncate">${item.type}</p>
            <p class="text-white/70 text-xs">${item.dimensions || ''}</p>
          </div>
        </button>
      `
    }).join("")
  }

  filterProduct(event) {
    const product = event.currentTarget.dataset.product
    this.activeProduct = product
    this.applyFilters()
  }

  filterType() {
    this.activeType = this.typeFilterTarget.value
    this.applyFilters()
  }

  updateFilterUI() {
    const buttons = {}
    if (this.hasFilterAllTarget) buttons.all = this.filterAllTarget
    if (this.hasFilterCrmTarget) buttons.futuracrm = this.filterCrmTarget
    if (this.hasFilterFitnessTarget) buttons.futurafitness = this.filterFitnessTarget
    if (this.hasFilterDeliveryTarget) buttons.optimadelivery = this.filterDeliveryTarget
    if (this.hasFilterFuturaTarget) buttons.futura = this.filterFuturaTarget
    
    Object.entries(buttons).forEach(([product, btn]) => {
      if (product === this.activeProduct) {
        btn.classList.add("bg-accent", "text-white", "border-accent")
        btn.classList.remove("bg-bg-elevated", "text-content-muted")
      } else {
        btn.classList.remove("bg-accent", "text-white", "border-accent")
        btn.classList.add("bg-bg-elevated", "text-content-muted")
      }
    })
  }

  // === LIGHTBOX ===

  openLightbox(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const item = this.filteredContent[index]
    if (!item) return
    
    this.currentLightboxItem = item
    const isVideo = item.type === "video" || item.url.match(/\.(mp4|webm|mov)$/i)
    
    if (isVideo) {
      this.lightboxImageTarget.classList.add("hidden")
      this.lightboxVideoTarget.classList.remove("hidden")
      this.lightboxVideoTarget.src = item.url
    } else {
      this.lightboxVideoTarget.classList.add("hidden")
      this.lightboxVideoTarget.src = ""
      this.lightboxImageTarget.classList.remove("hidden")
      this.lightboxImageTarget.src = item.url
    }
    
    // Update metadata
    this.lightboxProductTarget.textContent = item.product || "Unknown"
    this.lightboxTypeTarget.textContent = item.type || "Image"
    this.lightboxDimensionsTarget.textContent = item.dimensions || ""
    this.lightboxBatchTarget.textContent = `Batch: ${item.batch} • ${this.formatDate(item.batchDate)}`
    this.lightboxPromptTarget.textContent = item.prompt || "No prompt available"
    
    // Show lightbox
    this.lightboxTarget.classList.remove("hidden")
    this.lightboxTarget.classList.add("flex")
    document.body.classList.add("overflow-hidden")
  }

  closeLightbox() {
    this.lightboxTarget.classList.add("hidden")
    this.lightboxTarget.classList.remove("flex")
    document.body.classList.remove("overflow-hidden")
    
    // Stop video if playing
    this.lightboxVideoTarget.pause()
    this.lightboxVideoTarget.src = ""
    this.currentLightboxItem = null
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  useInPost() {
    if (!this.currentLightboxItem) return
    
    const url = this.currentLightboxItem.url
    const isVideo = this.currentLightboxItem.type === "video" || url.match(/\.(mp4|webm|mov)$/i)
    
    if (isVideo) {
      this.showToast("Videos cannot be used in posts yet", "warning")
      return
    }
    
    // Load image and convert to data URL for the post composer
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.onload = () => {
      const canvas = document.createElement("canvas")
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext("2d")
      ctx.drawImage(img, 0, 0)
      const dataUrl = canvas.toDataURL("image/png")
      this.setPostImage(dataUrl)
      this.closeLightbox()
      this.showToast("Image added to post!")
    }
    img.onerror = () => {
      this.showToast("Failed to load image", "error")
    }
    img.src = url
  }

  approveContent() {
    if (!this.currentLightboxItem) return
    
    const item = this.currentLightboxItem
    const itemKey = `${item.batch}/${item.filename}`
    
    // Check if already approved
    if (this.approvedItems.includes(itemKey)) {
      this.showToast("Already approved!", "warning")
      return
    }
    
    // Add to approved list
    this.approvedItems.push(itemKey)
    this.saveApprovedItems()
    
    // Re-render to show badge
    this.renderContentGallery()
    
    this.showToast("Content approved! 👍")
    this.closeLightbox()
  }
  
  isApproved(item) {
    const itemKey = `${item.batch}/${item.filename}`
    return this.approvedItems.includes(itemKey)
  }

  formatDate(dateString) {
    if (!dateString) return ""
    try {
      const date = new Date(dateString)
      return date.toLocaleDateString("en-US", { 
        month: "short", 
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      })
    } catch {
      return dateString
    }
  }

  // === IMAGE GENERATION ===
  
  async generateImage(variantSeed = 0) {
    const prompt = this.promptTarget.value.trim()
    if (!prompt) {
      this.showToast("Please enter a prompt", "warning")
      return null
    }

    const model = this.hasModelTarget ? this.modelTarget.value : "gpt-image-1"
    const product = this.hasProductTarget ? this.productTarget.value : "futura"
    const template = this.hasTemplateTarget ? this.templateTarget.value : "none"
    const size = this.hasSizeTarget ? this.sizeTarget.value : "1024x1024"

    // Check if model is supported
    if (model !== "gpt-image-1") {
      this.showToast("This model is coming soon!", "warning")
      return null
    }

    // Show loading state (only for main generation, not variants)
    if (variantSeed === 0) {
      this.generateTextTarget.classList.add("hidden")
      this.generateSpinnerTarget.classList.remove("hidden")
      this.generateBtnTarget.disabled = true
      
      // Update preview to show loading
      this.imagePreviewTarget.innerHTML = `
        <div class="text-center text-content-muted">
          <div class="text-4xl mb-2 animate-pulse">🎨</div>
          <p class="text-sm">Generating with ${model}...</p>
          <p class="text-xs mt-1 text-content-muted">This may take 30-60 seconds</p>
        </div>
      `
    }

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      
      const response = await fetch("/marketing/generate_image", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify({
          prompt: prompt,
          model: model,
          product: product,
          template: template,
          size: size,
          variant_seed: variantSeed
        })
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "Generation failed")
      }

      // Success! Display the image (only for main generation)
      if (variantSeed === 0) {
        this.displayGeneratedImage(data.url, data)
        this.addToGalleryUrl(data.url)
        
        // Store last generation params for variants
        this.lastGenerationParams = { prompt, model, product, template, size }
        
        // Show variants button
        if (this.hasVariantsBtnTarget) {
          this.variantsBtnTarget.classList.remove("hidden")
        }
        
        // Refresh content library to show the new image
        this.loadContentLibrary()
        
        this.showToast("Image generated! 🎉")
      }

      return data

    } catch (error) {
      console.error("Image generation failed:", error)
      if (variantSeed === 0) {
        this.imagePreviewTarget.innerHTML = `
          <div class="text-center text-red-400">
            <div class="text-4xl mb-2">❌</div>
            <p class="text-sm">Generation failed</p>
            <p class="text-xs mt-1">${error.message}</p>
          </div>
        `
        this.showToast(error.message || "Generation failed", "error")
      }
      return null
    } finally {
      // Reset button state (only for main generation)
      if (variantSeed === 0) {
        this.generateTextTarget.classList.remove("hidden")
        this.generateSpinnerTarget.classList.add("hidden")
        this.generateBtnTarget.disabled = false
      }
    }
  }

  async generateVariants() {
    if (!this.lastGenerationParams) {
      this.showToast("Generate an image first!", "warning")
      return
    }

    // Show loading state
    if (this.hasVariantsTextTarget) this.variantsTextTarget.classList.add("hidden")
    if (this.hasVariantsSpinnerTarget) this.variantsSpinnerTarget.classList.remove("hidden")
    if (this.hasVariantsBtnTarget) this.variantsBtnTarget.disabled = true

    // Show variants container with loading state
    if (this.hasVariantsContainerTarget) {
      this.variantsContainerTarget.classList.remove("hidden")
      this.variantsRowTarget.innerHTML = `
        <div class="aspect-square bg-bg-elevated rounded-lg animate-pulse flex items-center justify-center">
          <span class="text-content-muted text-2xl">1️⃣</span>
        </div>
        <div class="aspect-square bg-bg-elevated rounded-lg animate-pulse flex items-center justify-center">
          <span class="text-content-muted text-2xl">2️⃣</span>
        </div>
        <div class="aspect-square bg-bg-elevated rounded-lg animate-pulse flex items-center justify-center">
          <span class="text-content-muted text-2xl">3️⃣</span>
        </div>
      `
    }

    try {
      // Generate 3 variants concurrently with different seeds
      const variantPromises = [1, 2, 3].map(seed => this.generateVariantWithSeed(seed))
      const results = await Promise.allSettled(variantPromises)
      
      const successfulVariants = results
        .filter(r => r.status === "fulfilled" && r.value)
        .map(r => r.value)

      if (successfulVariants.length > 0) {
        // Display variants
        this.variantsRowTarget.innerHTML = successfulVariants.map((variant, i) => `
          <button 
            class="aspect-square rounded-lg overflow-hidden border-2 border-border hover:border-accent transition-colors"
            data-action="click->playground#selectVariant"
            data-url="${variant.url}"
          >
            <img src="${variant.url}" class="w-full h-full object-cover" alt="Variant ${i + 1}" />
          </button>
        `).join("")
        
        // Add variants to gallery
        successfulVariants.forEach(v => this.addToGalleryUrl(v.url))
        
        // Refresh content library
        this.loadContentLibrary()
        
        this.showToast(`${successfulVariants.length} variants generated! 🎉`)
      } else {
        this.variantsRowTarget.innerHTML = `
          <div class="col-span-3 text-center text-red-400 py-4">
            <p class="text-sm">Failed to generate variants</p>
          </div>
        `
        this.showToast("Failed to generate variants", "error")
      }

    } catch (error) {
      console.error("Variants generation failed:", error)
      this.showToast("Failed to generate variants", "error")
    } finally {
      // Reset button state
      if (this.hasVariantsTextTarget) this.variantsTextTarget.classList.remove("hidden")
      if (this.hasVariantsSpinnerTarget) this.variantsSpinnerTarget.classList.add("hidden")
      if (this.hasVariantsBtnTarget) this.variantsBtnTarget.disabled = false
    }
  }

  async generateVariantWithSeed(seed) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const params = this.lastGenerationParams

    const response = await fetch("/marketing/generate_image", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken || ""
      },
      body: JSON.stringify({
        prompt: params.prompt,
        model: params.model,
        product: params.product,
        template: params.template,
        size: params.size,
        variant_seed: seed
      })
    })

    if (!response.ok) {
      throw new Error("Variant generation failed")
    }

    return response.json()
  }

  selectVariant(event) {
    const url = event.currentTarget.dataset.url
    if (url) {
      this.displayGeneratedImage(url, { url })
      this.showToast("Variant selected!")
    }
  }

  displayGeneratedImage(url, metadata = null) {
    this.currentImageData = url
    this.currentImageMetadata = metadata
    
    const metaHtml = metadata ? `
      <div class="mt-2 text-xs text-content-muted">
        <span class="px-2 py-0.5 bg-accent/20 text-accent rounded">${metadata.product}</span>
        <span class="ml-2">${metadata.size}</span>
      </div>
    ` : ''
    
    this.imagePreviewTarget.innerHTML = `
      <div class="text-center">
        <img src="${url}" class="max-w-full max-h-64 rounded-lg mx-auto" alt="Generated image" />
        ${metaHtml}
      </div>
    `
    this.useImageBtnTarget.classList.remove("hidden")
  }

  useGeneratedImage() {
    if (this.currentImageData) {
      this.setPostImage(this.currentImageData)
      this.showToast("Image added to post!")
    }
  }

  addToGallery(dataUrl) {
    this.generatedImages.unshift(dataUrl)
    if (this.generatedImages.length > 8) {
      this.generatedImages.pop()
    }
    this.saveGallery()
    this.renderGallery()
  }

  addToGalleryUrl(url) {
    // For server-generated images, we store the URL directly
    // These will persist in the content library, but also show in recent gallery
    this.generatedImages.unshift(url)
    if (this.generatedImages.length > 8) {
      this.generatedImages.pop()
    }
    this.saveGallery()
    this.renderGallery()
  }

  renderGallery() {
    this.galleryTarget.innerHTML = this.generatedImages.map((img, index) => `
      <button 
        class="aspect-square rounded border border-border overflow-hidden hover:border-accent transition-colors"
        data-action="click->playground#selectGalleryImage"
        data-index="${index}"
      >
        <img src="${img}" class="w-full h-full object-cover" alt="Gallery image ${index + 1}" />
      </button>
    `).join("")
  }

  selectGalleryImage(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const img = this.generatedImages[index]
    if (img) {
      this.displayGeneratedImage(img)
    }
  }

  saveGallery() {
    try {
      localStorage.setItem("playground_gallery", JSON.stringify(this.generatedImages))
    } catch (e) {
      console.warn("Could not save gallery:", e)
    }
  }

  loadGallery() {
    try {
      const saved = localStorage.getItem("playground_gallery")
      if (saved) {
        this.generatedImages = JSON.parse(saved)
        this.renderGallery()
      }
    } catch (e) {
      console.warn("Could not load gallery:", e)
    }
  }

  clearGallery() {
    if (confirm("Clear all generated images?")) {
      this.generatedImages = []
      this.saveGallery()
      this.renderGallery()
      this.showToast("Gallery cleared")
    }
  }

  // === POST COMPOSER ===

  // Drag & Drop
  dragOver(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  dragEnter(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-accent", "bg-accent/10")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-accent", "bg-accent/10")
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-accent", "bg-accent/10")
    
    const files = event.dataTransfer?.files
    if (files && files[0]) {
      this.handleFile(files[0])
    }
  }

  clickUpload() {
    this.fileInputTarget.click()
  }

  fileSelected(event) {
    const file = event.target.files?.[0]
    if (file) {
      this.handleFile(file)
    }
  }

  handleFile(file) {
    if (!file.type.startsWith("image/")) {
      this.showToast("Please select an image file", "error")
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.setPostImage(e.target.result)
    }
    reader.readAsDataURL(file)
  }

  setPostImage(dataUrl) {
    this.currentImageData = dataUrl
    
    // Update post composer
    this.postImageTarget.src = dataUrl
    this.postImageTarget.classList.remove("hidden")
    this.dropZonePlaceholderTarget.classList.add("hidden")
    
    // Update previews
    this.fbImageTarget.src = dataUrl
    this.fbImageTarget.classList.remove("hidden")
    this.fbImagePlaceholderTarget.classList.add("hidden")
    
    this.igImageTarget.src = dataUrl
    this.igImageTarget.classList.remove("hidden")
    this.igImagePlaceholderTarget.classList.add("hidden")
    
    // Enable download
    this.downloadBtnTarget.disabled = false
    this.downloadBtnTarget.classList.remove("opacity-50", "cursor-not-allowed")
  }

  // Platform Toggle
  togglePlatform(event) {
    const platform = event.currentTarget.dataset.platform
    this.platforms[platform] = !this.platforms[platform]
    
    // Ensure at least one is selected
    if (!this.platforms.facebook && !this.platforms.instagram) {
      this.platforms[platform] = true
    }
    
    this.updatePlatformUI()
    this.updateCharCount()
  }

  updatePlatformUI() {
    // Facebook button
    if (this.platforms.facebook) {
      this.platformFbTarget.classList.add("bg-blue-600/20", "border-blue-500", "text-blue-400")
      this.platformFbTarget.classList.remove("bg-bg-elevated", "text-content-muted")
      this.fbPreviewContainerTarget.classList.remove("opacity-50")
    } else {
      this.platformFbTarget.classList.remove("bg-blue-600/20", "border-blue-500", "text-blue-400")
      this.platformFbTarget.classList.add("bg-bg-elevated", "text-content-muted")
      this.fbPreviewContainerTarget.classList.add("opacity-50")
    }
    
    // Instagram button
    if (this.platforms.instagram) {
      this.platformIgTarget.classList.add("bg-pink-600/20", "border-pink-500", "text-pink-400")
      this.platformIgTarget.classList.remove("bg-bg-elevated", "text-content-muted")
      this.igPreviewContainerTarget.classList.remove("opacity-50")
    } else {
      this.platformIgTarget.classList.remove("bg-pink-600/20", "border-pink-500", "text-pink-400")
      this.platformIgTarget.classList.add("bg-bg-elevated", "text-content-muted")
      this.igPreviewContainerTarget.classList.add("opacity-50")
    }
  }

  // Caption
  updateCaption() {
    this.updateCharCount()
    this.updatePreview()
  }

  updateCharCount() {
    const caption = this.captionTarget.value
    const length = caption.length
    
    // Use the smaller limit if both platforms, or specific platform limit
    let limit = 2200 // Instagram default
    if (this.platforms.facebook && !this.platforms.instagram) {
      limit = 63206
    }
    
    this.charCountTarget.textContent = `${length.toLocaleString()} / ${limit.toLocaleString()}`
    
    if (length > limit) {
      this.charCountTarget.classList.add("text-red-400")
    } else {
      this.charCountTarget.classList.remove("text-red-400")
    }
  }

  updatePreview() {
    const caption = this.captionTarget.value || "Your caption will appear here..."
    const hashtagString = this.hashtags.map(t => `#${t}`).join(" ")
    const fullCaption = hashtagString ? `${caption}\n\n${hashtagString}` : caption
    
    this.fbCaptionTarget.textContent = fullCaption
    this.igCaptionTarget.textContent = fullCaption
  }

  // Hashtags
  addHashtag(event) {
    if (event.key !== "Enter") return
    event.preventDefault()
    
    let tag = this.hashtagInputTarget.value.trim().replace(/^#/, "").replace(/\s+/g, "")
    if (!tag) return
    
    if (!this.hashtags.includes(tag)) {
      this.hashtags.push(tag)
      this.renderHashtags()
      this.updatePreview()
    }
    
    this.hashtagInputTarget.value = ""
  }

  addSuggestedHashtag(event) {
    const tag = event.currentTarget.dataset.tag
    if (!this.hashtags.includes(tag)) {
      this.hashtags.push(tag)
      this.renderHashtags()
      this.updatePreview()
    }
  }

  removeHashtag(event) {
    const tag = event.currentTarget.dataset.tag
    this.hashtags = this.hashtags.filter(t => t !== tag)
    this.renderHashtags()
    this.updatePreview()
  }

  renderHashtags() {
    this.hashtagContainerTarget.innerHTML = this.hashtags.map(tag => `
      <span class="inline-flex items-center gap-1 px-2 py-1 bg-accent/20 text-accent rounded-full text-sm">
        #${tag}
        <button 
          data-action="click->playground#removeHashtag" 
          data-tag="${tag}"
          class="hover:text-red-400 transition-colors"
        >×</button>
      </span>
    `).join("")
  }

  // === ACTIONS ===

  saveDraft() {
    const draft = {
      caption: this.captionTarget.value,
      hashtags: this.hashtags,
      cta: this.ctaTarget.value,
      platforms: this.platforms,
      image: this.currentImageData,
      savedAt: new Date().toISOString()
    }
    
    try {
      localStorage.setItem("playground_draft", JSON.stringify(draft))
      this.showToast("Draft saved!")
    } catch (e) {
      this.showToast("Could not save draft", "error")
    }
  }

  loadDraft() {
    try {
      const saved = localStorage.getItem("playground_draft")
      if (!saved) {
        this.showToast("No draft found", "warning")
        return
      }
      
      const draft = JSON.parse(saved)
      this.applyDraft(draft)
      this.showToast("Draft loaded!")
    } catch (e) {
      this.showToast("Could not load draft", "error")
    }
  }

  loadDraftOnStartup() {
    try {
      const saved = localStorage.getItem("playground_draft")
      if (saved) {
        const draft = JSON.parse(saved)
        // Only auto-load if saved recently (within 24 hours)
        if (draft.savedAt) {
          const savedDate = new Date(draft.savedAt)
          const hoursSince = (Date.now() - savedDate.getTime()) / (1000 * 60 * 60)
          if (hoursSince < 24) {
            this.applyDraft(draft)
          }
        }
      }
    } catch (e) {
      // Ignore errors on startup
    }
  }

  applyDraft(draft) {
    if (draft.caption) this.captionTarget.value = draft.caption
    if (draft.hashtags) {
      this.hashtags = draft.hashtags
      this.renderHashtags()
    }
    if (draft.cta) this.ctaTarget.value = draft.cta
    if (draft.platforms) {
      this.platforms = draft.platforms
      this.updatePlatformUI()
    }
    if (draft.image) {
      this.setPostImage(draft.image)
    }
    
    this.updateCharCount()
    this.updatePreview()
  }

  copyCaption() {
    const caption = this.captionTarget.value
    const hashtagString = this.hashtags.map(t => `#${t}`).join(" ")
    const fullCaption = hashtagString ? `${caption}\n\n${hashtagString}` : caption
    
    navigator.clipboard.writeText(fullCaption).then(() => {
      this.showToast("Caption copied!")
    }).catch(() => {
      this.showToast("Could not copy caption", "error")
    })
  }

  downloadImage() {
    if (!this.currentImageData) {
      this.showToast("No image to download", "warning")
      return
    }
    
    const link = document.createElement("a")
    link.download = `social-media-post-${Date.now()}.png`
    link.href = this.currentImageData
    link.click()
    
    this.showToast("Image downloaded!")
  }

  async approveAndQueue() {
    if (!this.currentImageData) {
      this.showToast("No image selected!", "warning")
      return
    }

    // Determine image URL - could be a server URL or data URL
    let imageUrl = this.currentImageData
    if (imageUrl.startsWith("data:")) {
      this.showToast("Please use a generated image from the API", "warning")
      return
    }

    const payload = {
      image_url: imageUrl,
      caption: this.captionTarget.value,
      hashtags: this.hashtags,
      cta: this.ctaTarget.value,
      platforms: this.platforms,
      product: this.hasProductTarget ? this.productTarget.value : "futura"
    }

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      
      const response = await fetch("/marketing/publish", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken || ""
        },
        body: JSON.stringify(payload)
      })

      const data = await response.json()

      if (data.success) {
        if (data.warning) {
          this.showToast(`Queued locally: ${data.warning}`, "warning")
        } else {
          this.showToast("Post queued for publishing! 🚀")
        }
        
        // Clear draft after successful queue
        localStorage.removeItem("playground_draft")
        
        console.log("Published to n8n:", data)
      } else {
        throw new Error(data.error || "Failed to queue post")
      }

    } catch (error) {
      console.error("Failed to queue post:", error)
      this.showToast(error.message || "Failed to queue post", "error")
    }
  }

  // === UTILITIES ===

  showToast(message, type = "success") {
    const colors = {
      success: "bg-green-600",
      error: "bg-red-600",
      warning: "bg-yellow-600"
    }
    
    this.toastTarget.className = `fixed bottom-6 right-6 px-4 py-3 ${colors[type]} text-white rounded-lg shadow-lg transform transition-all duration-300 z-50`
    this.toastMessageTarget.textContent = message
    
    // Show
    requestAnimationFrame(() => {
      this.toastTarget.classList.remove("translate-y-full", "opacity-0")
      this.toastTarget.classList.add("translate-y-0", "opacity-100")
    })
    
    // Hide after 3 seconds
    setTimeout(() => {
      this.toastTarget.classList.remove("translate-y-0", "opacity-100")
      this.toastTarget.classList.add("translate-y-full", "opacity-0")
    }, 3000)
  }
}
