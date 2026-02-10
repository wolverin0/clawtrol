import { Controller } from "@hotwired/stimulus"

// Marketing tree filter controller
export default class extends Controller {
  filter(event) {
    // Form auto-submits via turbo on change if needed
    // For instant client-side filter, we could add debounce + live filter here
  }
}
