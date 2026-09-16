import { Controller } from "@hotwired/stimulus"

// One-time plaintext copy (PRD-0007 DEV-0003 / issue #189): writes the
// targeted element's text to the OS clipboard and only then flips the panel
// into the copied state — a rejected write (missing permission) never claims
// success. The controller element carries the payload selector.
export default class extends Controller {
  copy() {
    const payload = document.querySelector(this.element.dataset.clipboardTarget)
    if (!payload) {
      return
    }
    navigator.clipboard.writeText(payload.textContent.trim()).then(() => {
      this.element.dataset.copied = "true"
      document.querySelector("#copy_token_plaintext").textContent = "Copied"
    })
  }
}