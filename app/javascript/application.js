// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Charts: chartkick + the self-contained Chart.js bundle (registers itself).
import "chartkick"
import "Chart.bundle"

// PWA: register the service worker (root scope) so the dashboard is installable.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch(() => {})
  })
}
