import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]

  connect() {
    this.reset()
  }

  start() {
    this.element.setAttribute("aria-busy", "true")

    // 送信する値を維持したまま、待機中の書き換えを防ぐ
    this.inputTargets.forEach((input) => {
      input.readOnly = true
    })

    this.statusTarget.textContent = "ミツメイトが返答を考えています。"
    this.statusTarget.hidden = false
  }

  finish(event) {
    this.reset()

    // サーバーの応答を確認できない場合は、入力を消さずに状況を伝える
    if (!event.detail.success && !event.detail.fetchResponse) {
      this.statusTarget.textContent =
        "通信状況を確認できませんでした。入力内容はこの画面に残しています。"
      this.statusTarget.hidden = false
    }
  }

  reset() {
    this.element.removeAttribute("aria-busy")

    this.inputTargets.forEach((input) => {
      input.readOnly = false
    })

    this.statusTarget.hidden = true
  }
}
