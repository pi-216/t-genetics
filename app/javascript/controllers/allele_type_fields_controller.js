// Issue #184 — type-aware allele form: reveal only the field group the
// selected allele type needs (Float/Integer → numeric, Option → choices,
// Boolean → none). Server-side validation is the source of truth; the
// toggle is pure presentation.
//
// Issue #211 — the edit form has no type select (the type is immutable and
// renders as read-only text), so the controller reads the server-rendered
// `type` value when the select is absent. Without that fallback the type was
// undefined on every edit and BOTH constraint groups started hidden, leaving
// the edit form with no way to change an allele's bounds or choices.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["numeric", "option"]
  static values = { type: String }

  connect() {
    this.select = this.element.querySelector("[data-allele-type-select]")
    if (this.select) {
      this.select.addEventListener("change", this.toggle.bind(this))
    }
    this.toggle()
  }

  toggle() {
    const type = this.select ? this.select.value : this.typeValue
    const numeric = type === "Float" || type === "Integer"
    this.numericTargets.forEach((el) => {
      el.hidden = !numeric
    })
    this.optionTargets.forEach((el) => {
      el.hidden = type !== "Option"
    })
  }
}