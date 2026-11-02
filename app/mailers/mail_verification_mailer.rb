class MailVerificationMailer < ApplicationMailer
  def check(recipient)
    mail(
      to: recipient,
      subject: "【わたしを辿る】本番環境からのメール送信テスト",
      body: <<~TEXT,
        「わたしを辿る」の本番環境から送信しています。

        RailsからBrevo APIを経由したメール送信の確認です。
        返信や操作は不要です。
      TEXT
      content_type: "text/plain; charset=UTF-8"
    )
  end
end
