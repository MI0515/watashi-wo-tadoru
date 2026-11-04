import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nickname", "honorific", "preview"]

  connect() {
    this.update()
  }

  update() {
    const value = this.nicknameTarget.value
    const nickname = value.trim() === "" ? "ニックネーム" : value

    this.previewTarget.textContent = nickname + this.honorificTarget.value
  }
}