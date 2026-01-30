import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="image-brightness"
export default class extends Controller {
  static targets = ["image"]
  static values = { threshold: Number, maxSize: Number }

  connect() {
    // Use default values if not provided
    this.threshold = this.hasThresholdValue ? this.thresholdValue : 180
    this.maxSize = this.hasMaxSizeValue ? this.maxSizeValue : 100

    this.analyzeImage()
  }

  analyzeImage() {
    const img = this.imageTarget

    // Wait for image to load if not already loaded
    if (img.complete && img.naturalWidth !== 0 && img.naturalHeight !== 0) {
      // Use requestAnimationFrame for smoother performance
      requestAnimationFrame(() => this.detectBrightness(img))
    } else {
      // Use AbortController for proper cleanup
      this.imageAbortController = new AbortController()
      const signal = this.imageAbortController.signal

      const handleLoad = () => {
        requestAnimationFrame(() => this.detectBrightness(img))
      }

      const handleError = () => {
        console.warn("Failed to load image for brightness detection")
        this.applyDefaultBorder(img)
      }

      img.addEventListener("load", handleLoad, { signal, once: true })
      img.addEventListener("error", handleError, { signal, once: true })
    }
  }

  disconnect() {
    // Clean up event listeners
    if (this.imageAbortController) {
      this.imageAbortController.abort()
    }
  }

  detectBrightness(img) {
    // Create a canvas to analyze the image
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d", { willReadFrequently: false })

    if (!ctx) {
      console.warn("Could not get canvas context for brightness detection")
      this.applyDefaultBorder(img)
      return
    }

    let width = img.naturalWidth || img.width
    let height = img.naturalHeight || img.height

    if (!width || !height) {
      console.warn("Image dimensions are invalid")
      this.applyDefaultBorder(img)
      return
    }

    // Scale down if too large to improve performance
    const scale = Math.min(this.maxSize / width, this.maxSize / height, 1)
    canvas.width = Math.floor(width * scale)
    canvas.height = Math.floor(height * scale)

    // Draw image to canvas
    try {
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)

      // Sample edge pixels (where border would be most visible)
      const sampleSize = Math.max(3, Math.floor(canvas.width * 0.1))
      let totalBrightness = 0
      let pixelCount = 0

      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const data = imageData.data

      // Optimize: sample fewer pixels but more strategically
      // Sample edges in a grid pattern for better performance
      const stride = Math.max(1, Math.floor(Math.min(canvas.width, canvas.height) / 20))

      // Sample left and right edges
      for (let y = 0; y < canvas.height; y += stride) {
        for (let x = 0; x < sampleSize; x++) {
          // Left edge
          const leftIdx = (y * canvas.width + x) * 4
          if (leftIdx + 2 < data.length) {
            totalBrightness += this.getBrightness(data[leftIdx], data[leftIdx + 1], data[leftIdx + 2])
            pixelCount++
          }

          // Right edge
          const rightX = canvas.width - 1 - x
          const rightIdx = (y * canvas.width + rightX) * 4
          if (rightIdx + 2 < data.length) {
            totalBrightness += this.getBrightness(data[rightIdx], data[rightIdx + 1], data[rightIdx + 2])
            pixelCount++
          }
        }
      }

      // Sample top and bottom edges
      for (let x = 0; x < canvas.width; x += stride) {
        for (let y = 0; y < sampleSize; y++) {
          // Top edge
          const topIdx = (y * canvas.width + x) * 4
          if (topIdx + 2 < data.length) {
            totalBrightness += this.getBrightness(data[topIdx], data[topIdx + 1], data[topIdx + 2])
            pixelCount++
          }

          // Bottom edge
          const bottomY = canvas.height - 1 - y
          const bottomIdx = (bottomY * canvas.width + x) * 4
          if (bottomIdx + 2 < data.length) {
            totalBrightness += this.getBrightness(data[bottomIdx], data[bottomIdx + 1], data[bottomIdx + 2])
            pixelCount++
          }
        }
      }

      if (pixelCount === 0) {
        this.applyDefaultBorder(img)
        return
      }

      const averageBrightness = totalBrightness / pixelCount
      const isLight = averageBrightness > this.threshold

      // Determine which element should get the border
      const borderElement = this.getBorderElement(img)

      // Toggle border classes based on brightness
      if (isLight) {
        borderElement.classList.add("border", "border-stone-200", "dark:border-white/20")
      } else {
        borderElement.classList.remove("border", "border-stone-200", "dark:border-white/20")
      }
    } catch (error) {
      // If canvas operations fail (CORS, etc.), apply default border
      console.warn("Could not analyze image brightness:", error)
      this.applyDefaultBorder(img)
    }
  }

  getBorderElement(img) {
    // Check if image has rounded corners, otherwise use container
    const roundedClasses = ["rounded", "rounded-md", "rounded-lg", "rounded-full"]
    const imageHasRounded = roundedClasses.some(className => img.classList.contains(className))
    return imageHasRounded ? img : this.element
  }

  applyDefaultBorder(img) {
    const borderElement = this.getBorderElement(img)
    borderElement.classList.add("border", "border-stone-200", "dark:border-white/20")
  }

  // Calculate perceived brightness using luminance formula
  // Luminance formula: 0.299*R + 0.587*G + 0.114*B
  getBrightness(r, g, b) {
    return 0.299 * r + 0.587 * g + 0.114 * b
  }
}

