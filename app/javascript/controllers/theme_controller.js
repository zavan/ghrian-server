import { Controller } from "@hotwired/stimulus"

// Toggles the dark theme by adding/removing `.dark` on <html> (Tailwind's
// class-based dark variant), persists the choice to localStorage, and keeps the
// theme-color meta in sync. The initial theme is applied in the layout's <head>
// to avoid a flash; with no saved choice the OS preference is followed (and
// tracked live below).
export default class extends Controller {
  static colors = { dark: "#0f172a", light: "#f1f5f9" }

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.onSystemChange = () => {
      if (!localStorage.getItem("theme")) this.apply(this.media.matches)
    }
    this.media.addEventListener("change", this.onSystemChange)
  }

  disconnect() {
    this.media?.removeEventListener("change", this.onSystemChange)
  }

  toggle() {
    const dark = !document.documentElement.classList.contains("dark")
    localStorage.setItem("theme", dark ? "dark" : "light")
    this.apply(dark)
  }

  apply(dark) {
    document.documentElement.classList.toggle("dark", dark)
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) meta.setAttribute("content", this.constructor.colors[dark ? "dark" : "light"])
  }
}
