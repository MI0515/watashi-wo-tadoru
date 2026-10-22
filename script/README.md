# Issue #30のOpenAI API検証

ローカルの技術検証用です。本番の画面・利用上限・安全対応の実装ではありません。決定事項と結果は[Issue #30](https://github.com/MI0515/watashi-wo-tadoru/issues/30)を参照してください。

## ファイル

- `verify_openai.rb`：ケースA・B・C・D・E・F1・F2の対話検証。通常はAI返信4回。
- `reflection_prompt.txt`：共通の対話指示。現行v7。メタ発言を抑える追記後の出力は未検証。
- `intp_reference.txt`：ケースEだけで渡すタイプ理論の参考情報。
- `verify_openai_summary.rb`：保存済みケースDから、まとめを1回生成する検証。
- `summary_prompt.txt`：まとめ用の指示。現行summary-v2。文体追記後の出力は未検証。
- `resume_openai.rb`：中断したケースBを復旧した一度限りのスクリプト。通常の再開には使わない。

## 実行前の注意

APIキーはローカルの`.env`に設定し、Compose経由で渡します。キーや会話ログをGitへ追加しないでください。
実行するとAPI料金が発生します。自動再試行はしません。#30の追加検証は終了しているため、確認だけの目的で再送する必要はありません。

## 対話検証

```bash
docker compose run --rm -e CASE=B web bin/rails runner script/verify_openai.rb
```

`CASE`で対象を指定します。参考返答は表示のみで、実際に送るのはターミナルに入力した文章です。`/exit`・空入力・入力終了で追加送信を止めます。
結果は`tmp/openai-verification/`へ保存します。同じ応答IDは費用集計で二重計上しないでください。

中断後は`RESUME`に同ディレクトリ内の記録ファイル名を指定すると、生成完了した返信の続きから再開できます。元の指示・設定を引き継ぎ、別ファイルに記録します。エラーや未完了の応答が含まれる記録は再開できません。

F2で最終返信が安全確認になっても、このスクリプトは4返信で終了します。安全確認後の継続を実装・検証したものではありません。

## まとめ検証

```bash
docker compose run --rm web bin/rails runner script/verify_openai_summary.rb
```

`tmp/openai-verification/case-d-20261022-102634-059465005.json`が必要です。ログはGit管理対象外のため、リポジトリを取得しただけでは実行できません。
別の記録で検証する場合は、スクリプトの読み込み先と検証条件を確認してから変更してください。

## APIを呼ばない確認

```bash
docker compose run --rm web ruby -c script/verify_openai.rb
docker compose run --rm web ruby -c script/verify_openai_summary.rb
docker compose run --rm web bundle exec rubocop
```
