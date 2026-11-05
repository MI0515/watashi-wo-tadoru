import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "radio", "selected"]

  connect() {
    this.update()
  }

  update() {
    this.optionTargets.forEach((option) => {
      const radio = option.querySelector('input[type="radio"]')
      option.classList.toggle("selected", radio.checked)
    })

    const selectedRadio = this.radioTargets.find((radio) => radio.checked)

    this.selectedTarget.textContent = selectedRadio
      ? selectedRadio.dataset.typeCode
      : "未選択"
  }
}