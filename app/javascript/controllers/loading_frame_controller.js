import { Controller } from "@hotwired/stimulus"

// Show skeleton loading state inside turbo-frames while they load
// Usage: <turbo-frame data-controller="loading-frame">
//          <div data-loading-frame-target="skeleton">...skeleton...</div>
//        </turbo-frame>
export default class extends Controller {
  static targets = ["skeleton"]

  connect() {
    this.element.addEventListener("turbo:before-fetch-request", () => this.showSkeleton())
    this.element.addEventListener("turbo:frame-load", () => this.hideSkeleton())
    this.element.addEventListener("turbo:fetch-request-error", () => this.hideSkeleton())
  }

  showSkeleton() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.remove("hidden")
    }
  }

  hideSkeleton() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.add("hidden")
    }
  }
}
