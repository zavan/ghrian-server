import { Controller } from "@hotwired/stimulus"

// Off-canvas navigation drawer for small screens. The hamburger button toggles
// it; it closes on Escape, on backdrop click, and after Turbo navigates (so
// tapping a link never leaves the drawer hanging open). On large screens the
// sidebar is pinned and the toggle/backdrop are hidden, so these are no-ops there.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  connect() {
    this.onKeydown = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKeydown)
    this.onVisit = () => this.close()
    document.addEventListener("turbo:load", this.onVisit)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:load", this.onVisit)
  }

  toggle() {
    this.setOpen(this.hasPanelTarget && this.panelTarget.classList.contains("-translate-x-full"))
  }

  open() { this.setOpen(true) }
  close() { this.setOpen(false) }

  setOpen(open) {
    if (this.hasPanelTarget) this.panelTarget.classList.toggle("-translate-x-full", !open)
    if (this.hasBackdropTarget) this.backdropTarget.classList.toggle("hidden", !open)
    document.body.classList.toggle("overflow-hidden", open)
  }
}
