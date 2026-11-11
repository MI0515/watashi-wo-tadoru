import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Turboのキャッシュによる仮表示中は、案内を開かない
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.element.showModal()
  }

  close() {
    this.element.close()
  }
}
