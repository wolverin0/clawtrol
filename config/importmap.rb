# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers/visualizer_controller", to: "controllers/visualizer_controller.js"
pin_all_from "app/javascript/helpers", under: "helpers"
pin_all_from "app/javascript/codemap", under: "codemap"
pin "sortablejs" # @1.15.6

# diff2html - GitHub-style diff viewer (UMD bundle, loaded as global via script tag)
# CSS loaded via stylesheet; JS accessed via window.Diff2Html in stimulus controller

# ActionCable for WebSocket channels
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"

# xterm.js for web terminal
pin "@xterm/xterm", to: "https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/+esm"
pin "@xterm/addon-fit", to: "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.10.0/+esm"

# D3.js for dependency graph visualization
pin "d3", to: "https://cdn.jsdelivr.net/npm/d3@7/+esm"

# Shared JS utilities
pin_all_from "app/javascript/utilities", under: "utilities"
