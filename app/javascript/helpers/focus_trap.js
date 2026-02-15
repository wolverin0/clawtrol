/**
 * Focus Trap Helper
 *
 * Traps focus within a container element. Used by modal controllers
 * for WCAG 2.1 compliance (keyboard-navigable dialogs).
 *
 * Usage:
 *   import { FocusTrap } from "helpers/focus_trap"
 *
 *   const trap = new FocusTrap(containerElement)
 *   trap.activate()   // saves previous focus, traps Tab, listens for Escape
 *   trap.deactivate() // restores previous focus, removes listeners
 */

const FOCUSABLE_SELECTOR = [
  'a[href]:not([tabindex="-1"])',
  'button:not([disabled]):not([tabindex="-1"])',
  'input:not([disabled]):not([tabindex="-1"])',
  'select:not([disabled]):not([tabindex="-1"])',
  'textarea:not([disabled]):not([tabindex="-1"])',
  '[tabindex]:not([tabindex="-1"])'
].join(", ")

export class FocusTrap {
  constructor(container, { onEscape = null, initialFocus = null } = {}) {
    this.container = container
    this.onEscape = onEscape
    this.initialFocus = initialFocus
    this._previouslyFocused = null
    this._boundKeydown = this._handleKeydown.bind(this)
    this._active = false
  }

  activate() {
    if (this._active) return
    this._active = true
    this._previouslyFocused = document.activeElement

    document.addEventListener("keydown", this._boundKeydown)

    // Focus initial element after next paint
    requestAnimationFrame(() => {
      const target =
        this.initialFocus ||
        this.container.querySelector("[autofocus]") ||
        this._focusableElements()[0]

      target?.focus()
    })
  }

  deactivate() {
    if (!this._active) return
    this._active = false

    document.removeEventListener("keydown", this._boundKeydown)

    if (this._previouslyFocused?.focus) {
      this._previouslyFocused.focus()
      this._previouslyFocused = null
    }
  }

  // --- Private ---

  _handleKeydown(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      if (this.onEscape) this.onEscape()
      return
    }

    if (event.key === "Tab") {
      this._trapTab(event)
    }
  }

  _trapTab(event) {
    const elements = this._focusableElements()
    if (elements.length === 0) return

    const first = elements[0]
    const last = elements[elements.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  _focusableElements() {
    return Array.from(
      this.container.querySelectorAll(FOCUSABLE_SELECTOR)
    ).filter(el => el.offsetParent !== null) // only visible elements
  }
}
