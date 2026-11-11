import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quote"]
  static values = { contents: Array }

  change() {
    // 独り言が1件もない性格タイプでは、ビューが quote 要素を出さない
    if (!this.hasQuoteTarget) return

    // タップしても同じ独り言が続かないように、表示中のものを候補から外す
    const currentContent = this.quoteTarget.textContent.trim()
    const candidates = this.contentsValue.filter(
      (content) => content.trim() !== currentContent
    )

    if (candidates.length === 0) return

    const index = Math.floor(Math.random() * candidates.length)
    this.quoteTarget.textContent = candidates[index]
  }
}
