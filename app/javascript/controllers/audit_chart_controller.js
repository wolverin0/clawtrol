import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["line", "bar"]
  static values = { data: Object }

  connect() {
    if (typeof window.Chart === "undefined") return

    const { labels = [], scores = [], anti_patterns: antiPatterns = [] } = this.dataValue || {}

    if (this.hasLineTarget) {
      this.lineChart = new window.Chart(this.lineTarget, {
        type: "line",
        data: {
          labels,
          datasets: [{
            label: "Overall Score",
            data: scores,
            borderColor: "#60a5fa",
            backgroundColor: "rgba(96, 165, 250, 0.2)",
            tension: 0.3,
            fill: true,
            pointRadius: 2
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            y: { min: 0, max: 10, ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.2)" } },
            x: { ticks: { color: "#94a3b8" }, grid: { display: false } }
          },
          plugins: { legend: { labels: { color: "#cbd5e1" } } }
        }
      })
    }

    if (this.hasBarTarget) {
      this.barChart = new window.Chart(this.barTarget, {
        type: "bar",
        data: {
          labels,
          datasets: [{
            label: "Anti-patterns",
            data: antiPatterns,
            backgroundColor: "rgba(248, 113, 113, 0.6)",
            borderRadius: 4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          scales: {
            y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(148, 163, 184, 0.2)" } },
            x: { ticks: { color: "#94a3b8" }, grid: { display: false } }
          },
          plugins: { legend: { labels: { color: "#cbd5e1" } } }
        }
      })
    }
  }

  disconnect() {
    this.lineChart?.destroy()
    this.barChart?.destroy()
  }
}
