import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "group", "option", "radio", "selected", "line"]

  connect() {
    this.updateGroups()
    this.select()
  }

  changeType() {
    this.radioTargets.forEach((radio) => {
      radio.checked = false
    })

    this.updateGroups()
    this.select()
  }

  updateGroups() {
    this.groupTargets.forEach((group) => {
      const active = group.dataset.typeId === this.typeTarget.value
      group.hidden = !active

      group.querySelectorAll('input[type="radio"]').forEach((radio) => {
        radio.disabled = !active
      })
    })
  }

  select() {
    this.optionTargets.forEach((option) => {
      const radio = option.querySelector('input[type="radio"]')
      option.classList.toggle("selected", radio.checked && !radio.disabled)
    })

    const selectedRadio = this.radioTargets.find(
      (radio) => radio.checked && !radio.disabled
    )

    this.selectedTarget.textContent = selectedRadio
      ? selectedRadio.dataset.label
      : "未選択"

    this.lineTarget.textContent = selectedRadio
      ? (selectedRadio.dataset.line ? `「${selectedRadio.dataset.line}」` : "")
      : "見た目を選ぶと、ミツメイトの言葉を表示します。"
  }
}