import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container", "status"]

  async connect() {
    this.term = null
    this.fitAddon = null
    this.channel = null
    this.resizeObserver = null

    try {
      // Dynamically import xterm modules
      const [xtermModule, fitModule] = await Promise.all([
        import("@xterm/xterm"),
        import("@xterm/addon-fit")
      ])

      const Terminal = xtermModule.Terminal
      const FitAddon = fitModule.FitAddon

      // Create terminal instance
      this.term = new Terminal({
        cursorBlink: true,
        cursorStyle: "bar",
        fontSize: 14,
        fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Menlo', 'Monaco', 'Courier New', monospace",
        theme: {
          background: "#0d1117",
          foreground: "#c9d1d9",
          cursor: "#58a6ff",
          selectionBackground: "#264f78",
          selectionForeground: "#ffffff",
          black: "#0d1117",
          red: "#ff7b72",
          green: "#3fb950",
          yellow: "#d29922",
          blue: "#58a6ff",
          magenta: "#bc8cff",
          cyan: "#39c5cf",
          white: "#b1bac4",
          brightBlack: "#6e7681",
          brightRed: "#ffa198",
          brightGreen: "#56d364",
          brightYellow: "#e3b341",
          brightBlue: "#79c0ff",
          brightMagenta: "#d2a8ff",
          brightCyan: "#56d4dd",
          brightWhite: "#f0f6fc"
        },
        scrollback: 5000,
        allowProposedApi: true
      })

      // Load fit addon
      this.fitAddon = new FitAddon()
      this.term.loadAddon(this.fitAddon)

      // Open terminal in container
      this.term.open(this.containerTarget)

      // Initial fit
      requestAnimationFrame(() => {
        this.fitAddon.fit()
      })

      // Setup resize observer
      this.resizeObserver = new ResizeObserver(() => {
        this.handleResize()
      })
      this.resizeObserver.observe(this.containerTarget)

      // Handle window resize
      this.boundHandleResize = this.handleResize.bind(this)
      window.addEventListener("resize", this.boundHandleResize)

      // Setup ActionCable connection
      this.setupChannel()

      // Handle terminal input
      this.term.onData((data) => {
        if (this.channel) {
          this.channel.send({ type: "input", data: data })
        }
      })

      // Handle paste via right-click context menu or keyboard
      this.term.attachCustomKeyEventHandler((event) => {
        // Allow Ctrl+C / Cmd+C for copy
        if ((event.ctrlKey || event.metaKey) && event.key === "c" && this.term.hasSelection()) {
          navigator.clipboard.writeText(this.term.getSelection())
          return false
        }
        // Allow Ctrl+V / Cmd+V for paste
        if ((event.ctrlKey || event.metaKey) && event.key === "v") {
          navigator.clipboard.readText().then((text) => {
            if (this.channel) {
              this.channel.send({ type: "input", data: text })
            }
          }).catch(() => {})
          return false
        }
        return true
      })

      this.updateStatus("connected")

    } catch (error) {
      console.error("Failed to initialize terminal:", error)
      this.updateStatus("error")
    }
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }

    if (this.boundHandleResize) {
      window.removeEventListener("resize", this.boundHandleResize)
    }

    if (this.channel) {
      this.channel.unsubscribe()
      this.channel = null
    }

    if (this.term) {
      this.term.dispose()
      this.term = null
    }
  }

  setupChannel() {
    const consumer = createConsumer()

    this.channel = consumer.subscriptions.create("TerminalChannel", {
      connected: () => {
        console.log("Terminal channel connected")
        this.updateStatus("connected")
        // Send initial resize
        requestAnimationFrame(() => {
          this.sendResize()
        })
      },

      disconnected: () => {
        console.log("Terminal channel disconnected")
        this.updateStatus("disconnected")
      },

      received: (data) => {
        if (data.type === "output" && this.term) {
          this.term.write(data.data)
        } else if (data.type === "exit") {
          this.updateStatus("exited")
          if (this.term) {
            this.term.write("\r\n\x1b[33m[Process exited. Press any key to reconnect...]\x1b[0m\r\n")
            // Allow reconnect on keypress
            const disposable = this.term.onData(() => {
              disposable.dispose()
              this.reconnect()
            })
          }
        }
      }
    })
  }

  handleResize() {
    if (this.fitAddon && this.term) {
      try {
        this.fitAddon.fit()
        this.sendResize()
      } catch (e) {
        // Ignore resize errors during teardown
      }
    }
  }

  sendResize() {
    if (this.channel && this.term) {
      this.channel.send({
        type: "resize",
        cols: this.term.cols,
        rows: this.term.rows
      })
    }
  }

  reconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
    this.setupChannel()
    this.updateStatus("reconnecting")
  }

  updateStatus(status) {
    if (this.hasStatusTarget) {
      const statusEl = this.statusTarget
      const dot = statusEl.querySelector(".status-dot")
      const text = statusEl.querySelector(".status-text")

      if (dot) {
        dot.className = "status-dot w-2 h-2 rounded-full inline-block mr-1.5"
        switch (status) {
          case "connected":
            dot.classList.add("bg-green-500")
            break
          case "disconnected":
          case "error":
            dot.classList.add("bg-red-500")
            break
          case "reconnecting":
            dot.classList.add("bg-yellow-500")
            break
          case "exited":
            dot.classList.add("bg-gray-500")
            break
        }
      }

      if (text) {
        text.textContent = status.charAt(0).toUpperCase() + status.slice(1)
      }
    }
  }

  clearTerminal() {
    if (this.term) {
      this.term.clear()
    }
  }
}
