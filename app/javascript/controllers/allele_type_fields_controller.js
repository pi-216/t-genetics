// Issue #184 — type-aware allele form: reveal only the field group the
// selected allele type needs (Float/Integer → numeric, Option → choices,
// Boolean → none). Server-side validation is the source of truth; the
// toggle is pure presentation.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["numeric", "option"]

  connect() {
    this.select = this.element.querySelector("[data-allele-type-select]")
    if (this.select) {
      this.select.addEventListener("change", this.toggle.bind(this))
    }
    this.toggle()
  }

  toggle() {
    const type = this.select?.value
    const numeric = type === "Float" || type === "Integer"
    this.numericTargets.forEach((el) => {
      el.hidden = !numeric
    })
    this.optionTargets.forEach((el) => {
      el.hidden = type !== "Option"
    })
  }
}