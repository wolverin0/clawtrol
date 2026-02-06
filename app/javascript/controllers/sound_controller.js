import { Controller } from "@hotwired/stimulus"

/**
 * Codec Sound Effects Controller - MGS-inspired Easter egg
 * 
 * Plays short beep sounds for various UI events.
 * Sounds are stored in /public/sounds/ and preference in localStorage.
 * 
 * Usage:
 *   <div data-controller="sound">
 *     <button data-action="click->sound#play" data-sound-sound-param="codec_call">Open</button>
 *   </div>
 * 
 * Global dispatch:
 *   document.dispatchEvent(new CustomEvent("codec:play", { detail: { sound: "agent_complete" } }))
 */
export default class extends Controller {
  static values = {
    enabled: { type: Boolean, default: true },
    volume: { type: Number, default: 0.3 }
  }

  connect() {
    // Load preference from localStorage
    const stored = localStorage.getItem("codecSounds")
    this.enabledValue = stored !== "false"

    // Preload audio cache for instant playback
    this.audioCache = {}
    const sounds = ["codec_call", "codec_close", "agent_spawn", "agent_complete", "agent_error"]
    sounds.forEach(name => {
      const audio = new Audio(`/sounds/${name}.mp3`)
      audio.volume = this.volumeValue
      audio.preload = "auto"
      this.audioCache[name] = audio
    })

    // Listen for global codec:play events (fired from other controllers)
    this.handleGlobalPlay = this.handleGlobalPlay.bind(this)
    document.addEventListener("codec:play", this.handleGlobalPlay)
  }

  disconnect() {
    document.removeEventListener("codec:play", this.handleGlobalPlay)
    this.audioCache = {}
  }

  /**
   * Play a sound by name (from data-sound-sound-param)
   * Usage: data-action="click->sound#play" data-sound-sound-param="codec_call"
   */
  play(event) {
    if (!this.enabledValue) return
    const sound = event?.params?.sound
    if (sound) this._playSound(sound)
  }

  /**
   * Handle global codec:play events
   */
  handleGlobalPlay(event) {
    if (!this.enabledValue) return
    const sound = event?.detail?.sound
    if (sound) this._playSound(sound)
  }

  /**
   * Toggle sound on/off
   */
  toggle() {
    this.enabledValue = !this.enabledValue
    localStorage.setItem("codecSounds", this.enabledValue)

    // Play a confirmation beep when enabling
    if (this.enabledValue) {
      this._playSound("codec_call")
    }

    // Dispatch event so other UI can react (e.g., toggle button text)
    this.dispatch("toggled", { detail: { enabled: this.enabledValue } })
  }

  /**
   * Internal: play a sound by name
   */
  _playSound(name) {
    try {
      const cached = this.audioCache[name]
      if (cached) {
        // Clone the audio node for overlapping plays
        const clone = cached.cloneNode()
        clone.volume = this.volumeValue
        clone.play().catch(() => {})
      } else {
        // Fallback: create on-the-fly
        const audio = new Audio(`/sounds/${name}.mp3`)
        audio.volume = this.volumeValue
        audio.play().catch(() => {})
      }
    } catch {
      // Silently fail - sound is an Easter egg, not critical
    }
  }
}
