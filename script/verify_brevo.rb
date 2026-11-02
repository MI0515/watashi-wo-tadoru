# 実行方法：bin/rails runner script/verify_brevo.rb
# 宛先は環境変数BREVO_TEST_TOで指定する。

abort "このスクリプトは本番環境で実行してください。" unless Rails.env.production?

recipient = ENV.fetch("BREVO_TEST_TO")
abort "テスト送信先が空です。" if recipient.blank?

MailVerificationMailer.check(recipient).deliver_now

puts "Brevo APIへの送信処理が完了しました。受信メールを確認してください。"
