import { Controller } from "@hotwired/stimulus"

/**
 * Infinite Scroll Controller
 * 
 * Detects when user scrolls near the bottom of a container and
 * fetches the next page of results via AJAX.
 * 
 * Usage:
 *   <div data-controller="infinite-scroll"
 *        data-infinite-scroll-url-value="/path/to/resource"
 *        data-infinite-scroll-page-value="1"
 *        data-infinite-scroll-has-more-value="true">
 *     <div data-infinite-scroll-target="container">
 *       <!-- scrollable content -->
 *     </div>
 *     <div data-infinite-scroll-target="entries">
 *       <!-- items to append to -->
 *     </div>
 *     <div data-infinite-scroll-target="loader" class="hidden">
 *       Loading...
 *     </div>
 *     <div data-infinite-scroll-target="sentinel"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["container", "entries", "loader", "sentinel"]
  static values = {
    url: String,
    page: { type: Number, default: 1 },
    hasMore: { type: Boolean, default: true },
    threshold: { type: Number, default: 200 } // pixels from bottom to trigger load
  }

  connect() {
    this.loading = false
    
    // Use IntersectionObserver if sentinel target exists
    if (this.hasSentinelTarget) {
      this.setupIntersectionObserver()
    } else {
      // Fallback to scroll event
      this.setupScrollListener()
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.scrollHandler) {
      this.scrollElement.removeEventListener("scroll", this.scrollHandler)
    }
  }

  setupIntersectionObserver() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !this.loading && this.hasMoreValue) {
            this.loadMore()
          }
        })
      },
      {
        root: this.hasContainerTarget ? this.containerTarget : null,
        rootMargin: `${this.thresholdValue}px`,
        threshold: 0
      }
    )

    this.observer.observe(this.sentinelTarget)
  }

  setupScrollListener() {
    this.scrollElement = this.hasContainerTarget ? this.containerTarget : window
    
    this.scrollHandler = this.debounce(() => {
      if (!this.loading && this.hasMoreValue && this.nearBottom()) {
        this.loadMore()
      }
    }, 100)

    this.scrollElement.addEventListener("scroll", this.scrollHandler, { passive: true })
  }

  nearBottom() {
    const element = this.hasContainerTarget ? this.containerTarget : document.documentElement
    const scrollTop = this.hasContainerTarget ? element.scrollTop : window.scrollY
    const scrollHeight = element.scrollHeight
    const clientHeight = this.hasContainerTarget ? element.clientHeight : window.innerHeight

    return scrollTop + clientHeight >= scrollHeight - this.thresholdValue
  }

  async loadMore() {
    if (this.loading || !this.hasMoreValue) return

    this.loading = true
    this.showLoader()

    const nextPage = this.pageValue + 1
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", nextPage)

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const html = await response.text()

      if (html.trim()) {
        // Append the new rows
        this.entriesTarget.insertAdjacentHTML("beforeend", html)
        this.pageValue = nextPage

        // Check if we got a partial page (less content = no more pages)
        // The server can also send X-Has-More header
        const hasMoreHeader = response.headers.get("X-Has-More")
        if (hasMoreHeader !== null) {
          this.hasMoreValue = hasMoreHeader === "true"
        }
      } else {
        // Empty response means no more pages
        this.hasMoreValue = false
      }
    } catch (error) {
      console.error("Infinite scroll error:", error)
      // Don't retry immediately on error
      this.hasMoreValue = false
    } finally {
      this.loading = false
      this.hideLoader()
      this.updateEndState()
    }
  }

  showLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.remove("hidden")
    }
  }

  hideLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.add("hidden")
    }
  }

  updateEndState() {
    if (!this.hasMoreValue) {
      // Hide sentinel when no more pages
      if (this.hasSentinelTarget) {
        this.sentinelTarget.classList.add("hidden")
      }
    }
  }

  debounce(func, wait) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = setTimeout(() => func.apply(this, args), wait)
    }
  }

  // Allow manual trigger (e.g., from a "Load More" button)
  load(event) {
    if (event) event.preventDefault()
    this.loadMore()
  }
}
