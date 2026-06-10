import { Controller } from "@hotwired/stimulus"

// One-click copy: writes the source target's text to the clipboard and briefly
// swaps the button label to confirm.
export default class extends Controller {
  static targets = ["source", "label"]
  static values = { copied: { type: String, default: "Copied!" } }

  copy() {
    navigator.clipboard
      .writeText(this.sourceTarget.textContent.trim())
      .then(() => this.flashLabel())
  }

  flashLabel() {
    if (!this.hasLabelTarget) return

    const original = this.labelTarget.textContent
    this.labelTarget.textContent = this.copiedValue
    setTimeout(() => (this.labelTarget.textContent = original), 1500)
  }
}
