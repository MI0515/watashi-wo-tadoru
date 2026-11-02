# 実行方法：bin/rails runner script/verify_brevo.rb
# 宛先は環境変数BREVO_TEST_TOで指定する。

abort "このスクリプトは本番環境で実行してください。" unless Rails.env.production?

recipient = ENV.fetch("BREVO_TEST_TO")
abort "テスト送信先が空です。" if recipient.blank?

ApplicationMailer.mail(
  to: recipient,
  subject: "【わたしを辿る】本番環境からのメール送信テスト",
  body: <<~TEXT,
    「わたしを辿る」の本番環境から送信しています。

    RailsからBrevo APIを経由したメール送信の確認です。
    返信や操作は不要です。
  TEXT
  content_type: "text/plain; charset=UTF-8"
).deliver_now

puts "Brevo APIへの送信処理が完了しました。受信メールを確認してください。"
